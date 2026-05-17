defmodule Wololo.CivsByLeagueAPI do
  require Logger

  @base_url Application.compile_env(:wololo, :api_base_url)

  @league_order ["bronze", "silver", "gold", "platinum", "diamond", "conqueror"]

  @league_labels %{
    "bronze" => "Bronze",
    "silver" => "Silver",
    "gold" => "Gold",
    "platinum" => "Platinum",
    "diamond" => "Diamond",
    "conqueror" => "Conqueror"
  }

  def league_order, do: @league_order
  def league_labels, do: @league_labels

  @doc """
  Fetches civilization win rate data for all 6 main leagues in parallel.
  Returns {:ok, %{"bronze" => %{"civ_name" => win_rate, ...}, ...}} or {:error, reason}.
  """
  def fetch_all_leagues do
    cache_key = "civs_by_league_all"

    case Cachex.get(:wololo_cache, cache_key) do
      {:ok, nil} ->
        result = do_fetch_all_leagues()

        if match?({:ok, _}, result) do
          Cachex.put(:wololo_cache, cache_key, result, ttl: :timer.hours(24))
        end

        result

      {:ok, cached} ->
        cached

      {:error, _} ->
        do_fetch_all_leagues()
    end
  end

  defp do_fetch_all_leagues do
    tasks =
      Enum.map(@league_order, fn league ->
        Task.async(fn ->
          {league, fetch_league_data(league)}
        end)
      end)

    results = Task.await_many(tasks, 60_000)

    Enum.reduce_while(results, {:ok, %{}}, fn
      {league, {:ok, data}}, {:ok, acc} ->
        {:cont, {:ok, Map.put(acc, league, data)}}

      {league, {:error, reason}}, _acc ->
        Logger.error("Failed to fetch civs_by_league for #{league}: #{reason}")
        {:halt, {:error, "Failed to fetch data for #{league}: #{reason}"}}
    end)
  end

  @doc """
  Fetches civilization win rate data for a single league.
  Returns {:ok, %{"civ_name" => win_rate, ...}} or {:error, reason}.
  """
  def fetch_league_data(league) do
    cache_key = "civs_by_league_#{league}"

    case Cachex.get(:wololo_cache, cache_key) do
      {:ok, nil} ->
        result = make_api_request(league)

        if match?({:ok, _}, result) do
          Cachex.put(:wololo_cache, cache_key, result, ttl: :timer.hours(24))
        end

        result

      {:ok, cached} ->
        cached

      {:error, _} ->
        make_api_request(league)
    end
  end

  defp make_api_request(league) do
    url = "#{@base_url}/stats/rm_solo/civilizations?rank_level=#{URI.encode_www_form(league)}"
    Logger.info("Fetching civs_by_league data for #{league}")

    case Wololo.HTTPClient.get_with_retry(url) do
      {:ok, body} ->
        case Jason.decode(body) do
          {:ok, %{"data" => data}} when is_list(data) ->
            {:ok, transform_data(data)}

          {:ok, other} ->
            Logger.error("Unexpected API response structure: #{inspect(other)}")
            {:error, "Unexpected API response structure"}

          {:error, reason} ->
            Logger.error("JSON decode failed for civs_by_league: #{inspect(reason)}")
            {:error, "JSON decode failed: #{inspect(reason)}"}
        end

      {:error, reason} ->
        {:error, "civs_by_league API request failed: #{reason}"}
    end
  end

  defp transform_data(data) do
    Enum.reduce(data, %{}, fn
      %{"civilization" => civ, "win_rate" => wr}, acc when is_binary(civ) and is_number(wr) ->
        Map.put(acc, civ, Float.round(wr / 1, 2))

      entry, acc ->
        Logger.warning("Skipping malformed civs_by_league entry: #{inspect(entry)}")
        acc
    end)
  end
end
