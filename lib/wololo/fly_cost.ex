defmodule Wololo.FlyCost do
  @moduledoc """
  Estimates this app's monthly Fly.io hosting cost from live Machines.

  Fly does not expose Cost Explorer or invoices through a public API
  (`flyctl` has no billing command; GraphQL only has credit balance).
  This uses the Machines API plus published list prices for compute,
  dedicated IPv4, volumes, and extra certificates.
  """

  require Logger

  @cache_key "fly_monthly_cost"
  @cache_ttl :timer.minutes(30)
  @seconds_per_month 30 * 24 * 3600
  @graphql_url "https://api.fly.io/graphql"
  @machines_url_base "https://api.machines.dev/v1/apps"

  # Published 30-day price for a started shared-cpu-1x @ 2048MB (Aug 2026).
  # Fallback is the DFW rate, this app's primary region.
  @shared_1x_2gb_month %{
    "ams" => 11.11,
    "iad" => 10.70,
    "sjc" => 10.70,
    "ewr" => 10.70,
    "yyz" => 10.70,
    "ord" => 13.37,
    "dfw" => 13.37,
    "fra" => 12.34,
    "lhr" => 12.14,
    "cdg" => 12.14,
    "lax" => 12.83,
    "jnb" => 13.94,
    "gru" => 17.28,
    "sin" => 13.37,
    "nrt" => 13.37,
    "syd" => 13.37,
    "bom" => 12.14
  }

  @default_shared_1x_2gb 13.37
  @shared_cpu_256_per_second 0.00000078
  @included_ram_mb_per_shared_cpu 256
  @extra_ram_per_gb_month 5.0
  @stopped_rootfs_per_gb_month 0.15
  @default_stopped_rootfs_gb 1.0
  @dedicated_ipv4_month 2.0
  @volume_per_gb_month 0.15
  @extra_cert_month 0.10
  @free_certificates 10

  def cached do
    case Cachex.fetch(:wololo_cache, @cache_key, &fetch_for_cache/1) do
      {:ok, %{} = cost} -> cost
      {:commit, %{} = cost} -> cost
      {:ignore, _} -> nil
      _ -> nil
    end
  end

  def refresh do
    case fetch_and_estimate() do
      {:ok, cost} ->
        Cachex.put(:wololo_cache, @cache_key, cost, ttl: @cache_ttl)
        {:ok, cost}

      {:error, reason} = error ->
        Logger.warning("Fly cost refresh failed: #{inspect(reason)}")
        error
    end
  end

  defp fetch_for_cache(_key) do
    case fetch_and_estimate() do
      {:ok, cost} -> {:commit, cost, ttl: @cache_ttl}
      {:error, _reason} -> {:ignore, nil}
    end
  end

  def estimate_from_resources(resources) do
    machines = Map.get(resources, :machines, [])
    machine_total = machines |> Enum.map(&machine_monthly/1) |> Enum.sum()

    ipv4_total = Map.get(resources, :dedicated_ipv4_count, 0) * @dedicated_ipv4_month
    volume_total = Map.get(resources, :volume_gb, 0) * @volume_per_gb_month

    extra_certs = max(Map.get(resources, :certificate_count, 0) - @free_certificates, 0)
    cert_total = extra_certs * @extra_cert_month

    amount = Float.round(machine_total + ipv4_total + volume_total + cert_total, 2)
    rounded = amount |> Float.round() |> trunc()

    %{
      amount: amount,
      label: "$#{rounded}",
      tooltip:
        "About $#{:erlang.float_to_binary(amount, decimals: 2)}/month at current machine sizes (compute, IPs, volumes). Fly does not expose invoices via API, so bandwidth is not included."
    }
  end

  defp fetch_and_estimate do
    token = Application.get_env(:wololo, :fly_api_token)
    app = Application.get_env(:wololo, :fly_app_name) || "wololo"

    if is_binary(token) and token != "" do
      with {:ok, machines} <- fetch_machines(app, token),
           {:ok, extras} <- fetch_app_extras(app, token) do
        {:ok, estimate_from_resources(Map.put(extras, :machines, machines))}
      end
    else
      {:error, :missing_token}
    end
  end

  defp fetch_machines(app, token) do
    url = "#{@machines_url_base}/#{app}/machines"
    headers = [{"authorization", "Bearer #{token}"}, {"accept", "application/json"}]

    case Wololo.HTTPClient.get(url, headers) do
      {:ok, body} ->
        machines =
          body
          |> Jason.decode!()
          |> Enum.map(&normalize_machine/1)
          |> Enum.reject(&is_nil/1)

        {:ok, machines}

      {:error, reason} ->
        {:error, {:machines, reason}}
    end
  end

  defp fetch_app_extras(app, token) do
    query = """
    query($name: String!) {
      app(name: $name) {
        ipAddresses { nodes { type } }
        volumes { nodes { sizeGb } }
        certificates { nodes { hostname } }
      }
    }
    """

    body = Jason.encode!(%{query: query, variables: %{name: app}})

    headers = [
      {"authorization", "Bearer #{token}"},
      {"content-type", "application/json"}
    ]

    case Wololo.HTTPClient.post(@graphql_url, body, headers) do
      {:ok, response} ->
        app_data = get_in(Jason.decode!(response), ["data", "app"]) || %{}

        # Dedicated IPv4 is type "v4"; shared IPv4 is "shared_v4" and is free.
        dedicated_ipv4 =
          app_data
          |> get_in(["ipAddresses", "nodes"])
          |> List.wrap()
          |> Enum.count(&(&1["type"] == "v4"))

        volume_gb =
          app_data
          |> get_in(["volumes", "nodes"])
          |> List.wrap()
          |> Enum.map(&(&1["sizeGb"] || 0))
          |> Enum.sum()

        certs =
          app_data
          |> get_in(["certificates", "nodes"])
          |> List.wrap()
          |> length()

        {:ok,
         %{
           dedicated_ipv4_count: dedicated_ipv4,
           volume_gb: volume_gb,
           certificate_count: certs
         }}

      {:error, reason} ->
        {:error, {:graphql, reason}}
    end
  end

  defp normalize_machine(machine) when is_map(machine) do
    state = machine["state"]

    if state in ["destroyed", "destroying"] do
      nil
    else
      guest = get_in(machine, ["config", "guest"]) || %{}

      %{
        state: state,
        region: machine["region"],
        cpu_kind: guest["cpu_kind"] || "shared",
        cpus: guest["cpus"] || 1,
        memory_mb: guest["memory_mb"] || 256
      }
    end
  end

  defp normalize_machine(_), do: nil

  defp machine_monthly(%{state: state} = machine) when state in ["started", "starting"] do
    started_monthly(machine)
  end

  defp machine_monthly(%{state: state}) when state in ["stopped", "stopping", "suspended", "suspending"] do
    @default_stopped_rootfs_gb * @stopped_rootfs_per_gb_month
  end

  defp machine_monthly(_), do: 0.0

  defp started_monthly(%{cpu_kind: "shared", cpus: 1, memory_mb: 2048, region: region}) do
    Map.get(@shared_1x_2gb_month, region, @default_shared_1x_2gb)
  end

  defp started_monthly(%{cpu_kind: "shared", cpus: cpus, memory_mb: memory_mb, region: region}) do
    markup = shared_region_markup(region)
    extra_gb = max(memory_mb - @included_ram_mb_per_shared_cpu * cpus, 0) / 1024

    @shared_cpu_256_per_second * cpus * @seconds_per_month * markup +
      extra_gb * @extra_ram_per_gb_month * markup
  end

  defp started_monthly(%{cpus: cpus, memory_mb: memory_mb}) do
    # Performance-class fallback: published ~$31/mo for 1x @ 2GB in cheap regions,
    # plus $5/GB extra RAM.
    extra_gb = max(memory_mb - 2048 * cpus, 0) / 1024
    31.0 * cpus + extra_gb * @extra_ram_per_gb_month
  end

  defp shared_region_markup(region) do
    case Map.get(@shared_1x_2gb_month, region) do
      nil -> 1.0
      price -> price / @default_shared_1x_2gb
    end
  end
end
