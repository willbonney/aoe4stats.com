defmodule Wololo.CivsMetaAPI do
  require Logger
  alias Wololo.Civilizations

  @base_url Application.compile_env(:wololo, :api_base_url)

  def fetch_meta(league \\ nil) do
    cache_key = "civs_meta_#{league || "all"}"

    case Cachex.get(:wololo_cache, cache_key) do
      {:ok, nil} ->
        result = make_api_request(build_url(league))

        if match?({:ok, _}, result),
          do: Cachex.put(:wololo_cache, cache_key, result, ttl: :timer.hours(24))

        result

      {:ok, cached_result} ->
        cached_result

      {:error, _} ->
        make_api_request(build_url(league))
    end
  end

  defp build_url(league) do
    endpoint = "#{@base_url}/stats/rm_solo/civilizations"

    if league do
      "#{endpoint}?rank_level=#{URI.encode_www_form(league)}"
    else
      endpoint
    end
  end

  defp make_api_request(url) do
    case Wololo.HTTPClient.get_with_retry(url) do
      {:ok, body} ->
        case Jason.decode(body) do
          {:ok, decoded} -> {:ok, decoded}
          {:error, reason} ->
            Logger.error("Failed to decode civs meta JSON: #{inspect(reason)}")
            {:error, "Invalid JSON response"}
        end

      {:error, reason} ->
        {:error, "civs_meta make_api_request failed: #{reason}"}
    end
  end

  def transform_data(%{"data" => data}) when is_list(data) do
    by_slug = Map.new(Civilizations.all(), &{&1.slug, &1})

    data
    |> Enum.flat_map(fn row ->
      civ = by_slug[row["civilization"]]

      if civ && is_number(row["win_rate"]) && is_number(row["pick_rate"]) do
        [
          %{
            label: civ.label,
            image: civ.image,
            color: civ.color,
            win_rate: Float.round(row["win_rate"] / 1, 2),
            pick_rate: Float.round(row["pick_rate"] / 1, 2),
            games_count: row["games_count"],
            duration_median: row["duration_median"]
          }
        ]
      else
        []
      end
    end)
    |> Enum.sort_by(& &1.pick_rate, :desc)
  end

  def transform_data(_), do: []
end
