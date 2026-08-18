defmodule Wololo.AgeupsAPI do
  @moduledoc """
  Ranked 1v1 landmark / age-up stats from AoE4 World.

  The public ageups endpoint is not split by map. Opponent-specific win rates
  are available per landmark path via the matchups endpoint.
  """
  require Logger

  @base_url Application.compile_env(:wololo, :api_base_url)
  @fallback_patch "10604,10884,11214,11308"
  @ttl :timer.hours(24)
  @min_path_games 100
  @min_path_games_fallback 25
  @min_matchup_games 20
  @max_matchup_candidates 8
  @options_key "ageups_options"
  @updated_key :ageups_last_updated

  def fallback_patch, do: @fallback_patch

  @doc """
  Pulls the current age-up dataset and warms the cache.

  Intended for the daily leaderboard cron. Fetches query options plus the
  unfiltered rm_solo payload once, then prefetches opponent matchups for
  each civ's strongest paths.
  """
  def refresh_cache do
    Logger.info("[AgeupsAPI] Starting ageups cache refresh...")

    with {:ok, options} <- fetch_options_remote(),
         {:ok, payload} <- fetch_ageups_remote(options.patch) do
      warm_from_payload(options, payload, prefetch_matchups: true)
    else
      {:error, reason} = error ->
        Logger.error("[AgeupsAPI] Cache refresh failed: #{inspect(reason)}")
        error
    end
  end

  def warm_from_payload(options, payload, opts \\ []) do
    started = System.monotonic_time(:millisecond)
    patch = options.patch
    put_durable(@options_key, options)
    by_civ = parse_all_paths(payload)

    Enum.each(Wololo.Civilizations.slugs(), fn civ ->
      put_durable(paths_key(patch, civ), Map.get(by_civ, civ, []))
    end)

    matchups =
      if Keyword.get(opts, :prefetch_matchups, false) do
        prefetch_matchups(by_civ, patch)
      else
        0
      end

    recs = cache_recommendations(by_civ, patch)
    Cachex.put(:wololo_cache, @updated_key, DateTime.utc_now())

    duration = System.monotonic_time(:millisecond) - started

    Logger.info(
      "[AgeupsAPI] Cached paths for #{map_size(by_civ)} civs, #{matchups} matchup sets, #{recs} recommendations in #{duration}ms (#{patch})"
    )

    {:ok, %{civs: map_size(by_civ), matchups: matchups, recommendations: recs, patch: patch}}
  end

  def last_updated do
    case Cachex.get(:wololo_cache, @updated_key) do
      {:ok, %DateTime{} = ts} -> {:ok, ts}
      _ -> {:error, :not_found}
    end
  end

  def fetch_options do
    case cache_get(@options_key) do
      {:ok, opts} ->
        {:ok, opts}

      :miss ->
        case fetch_options_remote() do
          {:ok, _opts} = ok ->
            Cachex.put(:wololo_cache, @options_key, ok, ttl: @ttl)
            ok

          {:error, _} ->
            {:ok, %{patch: @fallback_patch, patch_label: @fallback_patch, raw: %{}}}
        end
    end
  end

  def fetch_paths(civ_slug, patch) when is_binary(civ_slug) and is_binary(patch) do
    key = paths_key(patch, civ_slug)

    case cache_get(key) do
      {:ok, paths} ->
        {:ok, paths}

      :miss ->
        url =
          "#{@base_url}/stats/analytics/ageups?" <>
            URI.encode_query(%{"kind" => "rm_solo", "patch" => patch, "civilization" => civ_slug})

        case get_json(url) do
          {:ok, payload} ->
            paths = parse_paths(payload, civ_slug)
            Cachex.put(:wololo_cache, key, {:ok, paths}, ttl: @ttl)
            {:ok, paths}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  def fetch_matchups(civ_slug, path, patch) when is_map(path) do
    key = matchup_key(patch, civ_slug, path)

    case cache_get(key) do
      {:ok, rows} ->
        {:ok, rows}

      :miss ->
        case fetch_matchups_remote(civ_slug, path, patch) do
          {:ok, _rows} = ok ->
            Cachex.put(:wololo_cache, key, ok, ttl: @ttl)
            ok

          error ->
            error
        end
    end
  end

  def parse_paths(payload, civ_slug) do
    Map.get(parse_all_paths(payload), civ_slug, [])
  end

  def parse_all_paths(%{"data" => data} = payload) when is_map(data) do
    metadata = index_metadata(payload["ageups_metadata"])

    (data["age1-4"] || [])
    |> Enum.filter(&complete_path?/1)
    |> Enum.group_by(& &1["civilization"])
    |> Enum.reject(fn {civ, _} -> civ in [nil, ""] end)
    |> Map.new(fn {civ, rows} ->
      paths =
        rows
        |> Enum.map(&row_to_path(&1, metadata))
        |> Enum.sort_by(&{&1.win_rate, &1.games}, :desc)

      {civ, paths}
    end)
  end

  def parse_all_paths(_), do: %{}

  def rec_key(patch, civ_slug, opponent) do
    "ageups_rec_#{patch}_#{civ_slug}_#{opponent || "any"}"
  end

  def cached_recommendation(civ_slug, opponent, patch) do
    cache_get(rec_key(patch, civ_slug, opponent))
  end

  def recommend_for(civ_slug, opponent, patch) do
    case cached_recommendation(civ_slug, opponent, patch) do
      {:ok, rec} ->
        {:ok, rec}

      :miss ->
        compute_and_store(civ_slug, opponent, patch)
    end
  end

  def cache_recommendations(by_civ, patch) when is_map(by_civ) do
    opponents = Wololo.Civilizations.slugs()

    Enum.reduce(by_civ, 0, fn {civ, paths}, count ->
      put_durable(rec_key(patch, civ, nil), recommend(paths))
      matchups = matchups_from_cache(civ, paths, patch)

      Enum.reduce(opponents, count + 1, fn
        ^civ, acc ->
          acc

        opp, acc ->
          rec = recommend(paths, opponent: opp, matchups: matchups)
          put_durable(rec_key(patch, civ, opp), rec)
          acc + 1
      end)
    end)
  end

  def recommend(paths, opts \\ []) when is_list(paths) do
    opponent = Keyword.get(opts, :opponent)
    matchups = Keyword.get(opts, :matchups, %{})

    candidates = eligible_paths(paths)

    cond do
      candidates == [] ->
        %{path: nil, alternatives: [], matchup: nil}

      is_binary(opponent) and opponent != "" ->
        recommend_vs(candidates, opponent, matchups)

      true ->
        [best | _rest] = candidates
        %{path: best, alternatives: alternatives(candidates, best), matchup: nil}
    end
  end

  def matchup_candidates(paths) do
    paths
    |> eligible_paths()
    |> Enum.take(@max_matchup_candidates)
  end

  def format_clock(nil), do: nil

  def format_clock(seconds) when is_number(seconds) do
    total = max(round(seconds), 0)
    minutes = div(total, 60)
    secs = rem(total, 60)
    "#{minutes}:#{String.pad_leading(Integer.to_string(secs), 2, "0")}"
  end

  def format_clock(_), do: nil

  defp recommend_vs(candidates, opponent, matchups) do
    scored =
      candidates
      |> Enum.flat_map(fn path ->
        case matchup_for(matchups, path, opponent) do
          %{games: games} = mu when games >= @min_matchup_games ->
            [{path, mu}]

          _ ->
            []
        end
      end)
      |> Enum.sort_by(fn {path, mu} -> {mu.win_rate, mu.games, path.games} end, :desc)

    case scored do
      [{best, mu} | _rest] ->
        %{
          path: best,
          alternatives: alternatives(candidates, best),
          matchup: mu
        }

      [] ->
        [best | _rest] = candidates
        %{path: best, alternatives: alternatives(candidates, best), matchup: matchup_for(matchups, best, opponent)}
    end
  end

  defp alternatives(candidates, best) do
    most_played = Enum.max_by(candidates, & &1.games, fn -> nil end)

    [most_played | candidates]
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq_by(&path_key/1)
    |> Enum.reject(&(path_key(&1) == path_key(best)))
    |> Enum.take(3)
  end

  defp matchup_for(matchups, path, opponent) do
    matchups
    |> Map.get(path_key(path), [])
    |> Enum.find(&(&1.opponent == opponent))
  end

  def path_key(path), do: "#{path.age2.pbgid}-#{path.age3.pbgid}-#{path.age4.pbgid}"

  defp eligible_paths(paths) do
    qualified = Enum.filter(paths, &(&1.games >= @min_path_games))

    cond do
      qualified != [] -> Enum.sort_by(qualified, &{&1.win_rate, &1.games}, :desc)
      true ->
        fallback = Enum.filter(paths, &(&1.games >= @min_path_games_fallback))
        list = if fallback != [], do: fallback, else: paths
        Enum.sort_by(list, &{&1.win_rate, &1.games}, :desc)
    end
  end

  defp complete_path?(row) do
    present?(row["age2_name"]) and present?(row["age3_name"]) and present?(row["age4_name"]) and
      not is_nil(row["age2_pbgid"]) and not is_nil(row["age3_pbgid"]) and not is_nil(row["age4_pbgid"])
  end

  defp present?(name) when is_binary(name), do: String.trim(name) != ""
  defp present?(_), do: false

  defp row_to_path(row, metadata) do
    %{
      civilization: row["civilization"],
      win_rate: to_float(row["win_rate"]),
      games: row["player_games_count"] || 0,
      wins: row["win_count"] || 0,
      duration_average: row["duration_average"],
      age2: landmark(row, 2, metadata),
      age3: landmark(row, 3, metadata),
      age4: landmark(row, 4, metadata)
    }
  end

  defp landmark(row, age, metadata) do
    pbgid = row["age#{age}_pbgid"]
    meta = metadata[pbgid] || %{}

    %{
      age: age,
      name: clean_name(row["age#{age}_name"]),
      pbgid: pbgid,
      icon: meta["icon"],
      finished_at: row["age#{age}_finished_at_average"]
    }
  end

  defp parse_matchups(rows) do
    Enum.flat_map(rows, fn row ->
      opp = row["opponent_civilization"]

      if is_binary(opp) and opp != "" do
        [
          %{
            opponent: opp,
            win_rate: to_float(row["win_rate"]),
            games: row["player_games_count"] || 0,
            wins: row["win_count"] || 0,
            duration_average: row["duration_average"]
          }
        ]
      else
        []
      end
    end)
  end

  defp index_metadata(list) when is_list(list) do
    Enum.reduce(list, %{}, fn
      %{"pbgid" => pbgid} = item, acc when not is_nil(pbgid) -> Map.put(acc, pbgid, item)
      _, acc -> acc
    end)
  end

  defp index_metadata(_), do: %{}

  defp clean_name(nil), do: nil

  defp clean_name(name) when is_binary(name) do
    name
    |> String.replace("\n", " ")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp clean_name(_), do: nil

  defp to_float(n) when is_number(n), do: n / 1
  defp to_float(_), do: 0.0

  defp patch_label(%{"patch" => %{"options" => options}}, patch) when is_list(options) do
    Enum.find_value(options, patch, fn
      %{"value" => ^patch, "label" => label} -> label
      _ -> nil
    end)
  end

  defp patch_label(_, patch), do: patch

  defp fetch_options_remote do
    case get_json("#{@base_url}/stats/analytics/ageups/query_options") do
      {:ok, %{"filter" => filter} = payload} ->
        patch = get_in(filter, ["patch", "default"]) || @fallback_patch
        {:ok, %{patch: patch, patch_label: patch_label(filter, patch), raw: payload}}

      {:ok, _} ->
        {:ok, %{patch: @fallback_patch, patch_label: @fallback_patch, raw: %{}}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_ageups_remote(patch) do
    url =
      "#{@base_url}/stats/analytics/ageups?" <>
        URI.encode_query(%{"kind" => "rm_solo", "patch" => patch})

    get_json(url)
  end

  defp fetch_matchups_remote(civ_slug, path, patch) do
    params = %{
      "kind" => "rm_solo",
      "patch" => patch,
      "civilization" => civ_slug,
      "age2_pbgid" => path.age2.pbgid,
      "age3_pbgid" => path.age3.pbgid,
      "age4_pbgid" => path.age4.pbgid
    }

    url = "#{@base_url}/stats/analytics/ageups/matchups?" <> URI.encode_query(params)

    case get_json(url) do
      {:ok, %{"data" => data}} when is_list(data) -> {:ok, parse_matchups(data)}
      {:ok, _} -> {:ok, []}
      {:error, reason} -> {:error, reason}
    end
  end

  defp prefetch_matchups(by_civ, patch) do
    jobs =
      for {civ, paths} <- by_civ,
          path <- matchup_candidates(paths) do
        {civ, path}
      end

    jobs
    |> Task.async_stream(
      fn {civ, path} ->
        case fetch_matchups_remote(civ, path, patch) do
          {:ok, rows} ->
            put_durable(matchup_key(patch, civ, path), rows)
            :ok

          {:error, reason} ->
            Logger.warning("[AgeupsAPI] matchup prefetch failed for #{civ}: #{inspect(reason)}")
            :error
        end
      end,
      max_concurrency: 3,
      timeout: 30_000,
      on_timeout: :kill_task
    )
    |> Enum.count(fn
      {:ok, :ok} -> true
      _ -> false
    end)
  end

  defp compute_and_store(civ_slug, opponent, patch) do
    with {:ok, paths} <- fetch_paths(civ_slug, patch) do
      rec =
        if is_binary(opponent) and opponent != "" do
          recommend(paths, opponent: opponent, matchups: load_matchups(civ_slug, paths, patch))
        else
          recommend(paths)
        end

      put_durable(rec_key(patch, civ_slug, opponent), rec)
      {:ok, rec}
    end
  end

  defp load_matchups(civ_slug, paths, patch) do
    paths
    |> matchup_candidates()
    |> Map.new(fn path ->
      rows =
        case fetch_matchups(civ_slug, path, patch) do
          {:ok, rows} -> rows
          _ -> []
        end

      {path_key(path), rows}
    end)
  end

  defp matchups_from_cache(civ_slug, paths, patch) do
    paths
    |> matchup_candidates()
    |> Map.new(fn path ->
      rows =
        case cache_get(matchup_key(patch, civ_slug, path)) do
          {:ok, rows} -> rows
          :miss -> []
        end

      {path_key(path), rows}
    end)
  end

  defp paths_key(patch, civ_slug), do: "ageups_paths_#{patch}_#{civ_slug}"

  defp matchup_key(patch, civ_slug, path) do
    "ageups_mu_#{patch}_#{civ_slug}_#{path.age2.pbgid}_#{path.age3.pbgid}_#{path.age4.pbgid}"
  end

  defp cache_get(key) do
    case Cachex.get(:wololo_cache, key) do
      {:ok, {:ok, value}} -> {:ok, value}
      _ -> :miss
    end
  end

  defp put_durable(key, value) do
    Cachex.put(:wololo_cache, key, {:ok, value})
  end

  defp http_client do
    Application.get_env(:wololo, :http_client, Wololo.HTTPClient)
  end

  defp get_json(url) do
    case http_client().get_with_retry(url) do
      {:ok, body} ->
        case Jason.decode(body) do
          {:ok, decoded} ->
            {:ok, decoded}

          {:error, reason} ->
            Logger.error("ageups JSON decode failed: #{inspect(reason)}")
            {:error, "Invalid JSON response"}
        end

      {:error, reason} ->
        {:error, "ageups request failed: #{reason}"}
    end
  end
end
