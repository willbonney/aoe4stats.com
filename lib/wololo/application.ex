defmodule Wololo.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      WololoWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:wololo, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Wololo.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Wololo.Finch},
      # Start a worker by calling: Wololo.Worker.start_link(arg)
      # {Wololo.Worker, arg},
      # Start to serve requests, typically the last entry
      WololoWeb.Endpoint,
      {Cachex, name: :wololo_cache}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Wololo.Supervisor]

    :logger.add_handler(:my_sentry_handler, Sentry.LoggerHandler, %{
      config: %{metadata: [:file, :line]}
    })

    result = Supervisor.start_link(children, opts)

    # Warm caches on boot if this machine has nothing yet.
    # Daily cron refreshes both via LeaderboardDumpCron.fetch_and_cache/0.
    if Application.get_env(:wololo, :cache_refresh_on_boot, true) do
      Task.start(fn ->
        leaderboard_empty? =
          case Cachex.get(:wololo_cache, "leaderboard_players") do
            {:ok, nil} -> true
            {:ok, _} -> false
            _ -> true
          end

        ageups_empty? =
          case Cachex.get(:wololo_cache, "ageups_options") do
            {:ok, {:ok, _}} -> false
            _ -> true
          end

        cond do
          leaderboard_empty? ->
            IO.puts("[Startup] Leaderboard cache is empty, triggering refresh...")
            Wololo.LeaderboardDumpCron.fetch_and_cache()

          ageups_empty? ->
            IO.puts("[Startup] Ageups cache is empty, triggering refresh...")
            Wololo.AgeupsAPI.refresh_cache()

          true ->
            IO.puts("[Startup] Leaderboard and ageups caches already populated")
        end
      end)
    end

    result
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    WololoWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
