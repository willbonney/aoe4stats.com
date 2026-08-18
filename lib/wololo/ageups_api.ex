defmodule Wololo.AgeupsAPI do
  @moduledoc """
  Ranked 1v1 landmark / age-up stats from AoE4 World.

  Paths can be filtered to the current RM solo map pool via `map_id`.
  Opponent-specific win rates come from the matchups endpoint.
  """
  require Logger

  @base_url Application.compile_env(:wololo, :api_base_url)
  @fallback_patch "10604,10884,11214,11308"
  @ttl :timer.hours(24)
  @min_path_games 100
  @min_path_games_fallback 25
  @min_matchup_games 20
  @max_matchup_candidates 8
  @max_map_matchup_candidates 20
  @options_key "ageups_options"
  @updated_key :ageups_last_updated

  def fallback_patch, do: @fallback_patch

  @doc """
  Pulls the current age-up dataset and warms the cache.

  Intended for the daily leaderboard cron. Fetches the unfiltered rm_solo
  payload plus every civ × current-season map combination, then prefetches
  opponent matchups for the strongest paths.
  """
  def refresh_cache do
    Logger.info("[AgeupsAPI] Starting ageups cache refresh...")

    with {:ok, options} <- fetch_options_remote(),
         {:ok, payload} <- fetch_ageups_remote(options.patch) do
      maps = current_season_maps()
      warm_from_payload(options, payload, prefetch_matchups: true, maps: maps)
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
        prefetch_civ_matchups(Wololo.Civilizations.slugs(), patch, nil)
        prefetch_matchups(by_civ, patch)
      else
        0
      end

    recs = cache_recommendations(by_civ, patch)
    maps = Keyword.get(opts, :maps, [])
    map_combos = warm_map_combos(patch, maps, opts)
    Cachex.put(:wololo_cache, @updated_key, DateTime.utc_now())

    duration = System.monotonic_time(:millisecond) - started

    Logger.info(
      "[AgeupsAPI] Cached paths for #{map_size(by_civ)} civs, #{length(maps)} maps, #{map_combos} map combos, #{matchups} matchup sets, #{recs} recommendations in #{duration}ms (#{patch})"
    )

    {:ok,
     %{
       civs: map_size(by_civ),
       maps: length(maps),
       map_combos: map_combos,
       matchups: matchups,
       recommendations: recs,
       patch: patch
     }}
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

  def fetch_paths(civ_slug, patch, map_id \\ nil)

  def fetch_paths(civ_slug, patch, map_id) when is_binary(civ_slug) and is_binary(patch) do
    key = paths_key(patch, civ_slug, map_id)

    case cache_get(key) do
      {:ok, paths} ->
        {:ok, paths}

      :miss ->
        opts = [civilization: civ_slug] ++ if(map_id, do: [map_id: map_id], else: [])

        case fetch_ageups_remote(patch, opts) do
          {:ok, payload} ->
            paths = parse_paths(payload, civ_slug)
            Cachex.put(:wololo_cache, key, {:ok, paths}, ttl: @ttl)
            {:ok, paths}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  def fetch_matchups(civ_slug, path, patch, map_id \\ nil)

  def fetch_matchups(civ_slug, path, patch, map_id) when is_map(path) do
    key = matchup_key(patch, civ_slug, path, map_id)

    case cache_get(key) do
      {:ok, rows} ->
        {:ok, rows}

      :miss ->
        case fetch_matchups_remote(civ_slug, path, patch, map_id) do
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

  def rec_key(patch, civ_slug, opponent, map_id \\ nil) do
    base = "ageups_rec_v2_#{patch}_#{civ_slug}_#{opponent || "any"}"
    if map_id, do: "#{base}_#{map_id}", else: base
  end

  def cached_recommendation(civ_slug, opponent, patch, map_id \\ nil) do
    cache_get(rec_key(patch, civ_slug, opponent, map_id))
  end

  def recommend_for(civ_slug, opponent, patch, map_id \\ nil) do
    case cached_recommendation(civ_slug, opponent, patch, map_id) do
      {:ok, rec} ->
        {:ok, rec}

      :miss ->
        compute_and_store(civ_slug, opponent, patch, map_id)
    end
  end

  def cache_recommendations(by_civ, patch, map_id \\ nil)

  def cache_recommendations(by_civ, patch, map_id) when is_map(by_civ) do
    opponents = Wololo.Civilizations.slugs()

    Enum.reduce(by_civ, 0, fn {civ, paths}, count ->
      put_durable(rec_key(patch, civ, nil, map_id), recommend(paths))
      matchups = matchups_from_cache(civ, paths, patch, map_id)
      civ_rows = civ_matchups_from_cache(civ, patch, map_id)

      Enum.reduce(opponents, count + 1, fn
        ^civ, acc ->
          acc

        opp, acc ->
          rec =
            paths
            |> recommend(opponent: opp, matchups: matchups)
            |> Map.put(:civ_matchup, civ_matchup_for(civ_rows, opp))

          put_durable(rec_key(patch, civ, opp, map_id), rec)
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
        %{path: nil, alternatives: [], matchup: nil, civ_matchup: nil}

      is_binary(opponent) and opponent != "" ->
        recommend_vs(candidates, opponent, matchups)

      true ->
        [best | _rest] = candidates
        %{path: best, alternatives: alternatives(candidates, best), matchup: nil, civ_matchup: nil}
    end
  end

  def matchup_candidates(paths, limit \\ @max_matchup_candidates) do
    paths
    |> eligible_paths()
    |> Enum.take(limit)
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
          %{games: games} = mu when games > 0 ->
            [{path, mu}]

          _ ->
            []
        end
      end)
      |> Enum.sort_by(
        fn {_path, mu} ->
          qualified = if mu.games >= @min_matchup_games, do: 1, else: 0
          {qualified, mu.win_rate, mu.games}
        end,
        :desc
      )

    case scored do
      [{best, mu} | rest] when mu.games >= @min_matchup_games ->
        %{
          path: best,
          alternatives: alternatives_from_matchups(rest),
          matchup: mu,
          civ_matchup: nil
        }

      _ ->
        [best | _rest] = candidates

        %{
          path: best,
          alternatives: alternatives_from_matchups(reject_path(scored, best)),
          matchup: matchup_for(matchups, best, opponent),
          civ_matchup: nil
        }
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

  defp alternatives_from_matchups(scored) do
    scored
    |> Enum.take(3)
    |> Enum.map(fn {path, mu} ->
      path
      |> Map.put(:win_rate, mu.win_rate)
      |> Map.put(:games, mu.games)
      |> Map.put(:wins, mu.wins)
    end)
  end

  defp reject_path(scored, path) do
    Enum.reject(scored, fn {other, _} -> path_key(other) == path_key(path) end)
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

  defp fetch_ageups_remote(patch, opts \\ []) do
    params =
      %{"kind" => "rm_solo", "patch" => patch}
      |> maybe_put("civilization", opts[:civilization])
      |> maybe_put("map_id", opts[:map_id])
      |> maybe_put("age2_pbgid", opts[:age2_pbgid])

    url = "#{@base_url}/stats/analytics/ageups?" <> URI.encode_query(params)
    get_json(url)
  end

  defp fetch_matchups_remote(civ_slug, path, patch, map_id) do
    params =
      %{
        "kind" => "rm_solo",
        "patch" => patch,
        "civilization" => civ_slug,
        "age2_pbgid" => path.age2.pbgid,
        "age3_pbgid" => path.age3.pbgid,
        "age4_pbgid" => path.age4.pbgid
      }
      |> maybe_put("map_id", map_id)

    url = "#{@base_url}/stats/analytics/ageups/matchups?" <> URI.encode_query(params)

    case get_json(url) do
      {:ok, %{"data" => data}} when is_list(data) -> {:ok, parse_matchups(data)}
      {:ok, _} -> {:ok, []}
      {:error, reason} -> {:error, reason}
    end
  end

  defp prefetch_matchups(by_civ, patch, map_id \\ nil) do
    jobs =
      for {civ, paths} <- by_civ,
          path <- matchup_candidates(paths, matchup_limit(map_id)) do
        {civ, path}
      end

    jobs
    |> Task.async_stream(
      fn {civ, path} ->
        case fetch_matchups_remote(civ, path, patch, map_id) do
          {:ok, rows} ->
            put_durable(matchup_key(patch, civ, path, map_id), rows)
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

  defp compute_and_store(civ_slug, opponent, patch, map_id) do
    with {:ok, paths} <- fetch_paths(civ_slug, patch, map_id) do
      rec =
        if is_binary(opponent) and opponent != "" do
          paths
          |> recommend(
            opponent: opponent,
            matchups: load_matchups(civ_slug, paths, patch, map_id)
          )
          |> Map.put(
            :civ_matchup,
            civ_matchup_for(load_civ_matchups(civ_slug, patch, map_id), opponent)
          )
        else
          recommend(paths)
        end

      put_durable(rec_key(patch, civ_slug, opponent, map_id), rec)
      {:ok, rec}
    end
  end

  defp load_matchups(civ_slug, paths, patch, map_id) do
    paths
    |> matchup_candidates(matchup_limit(map_id))
    |> Map.new(fn path ->
      rows =
        case fetch_matchups(civ_slug, path, patch, map_id) do
          {:ok, rows} -> rows
          _ -> []
        end

      {path_key(path), rows}
    end)
  end

  defp matchups_from_cache(civ_slug, paths, patch, map_id) do
    paths
    |> matchup_candidates(matchup_limit(map_id))
    |> Map.new(fn path ->
      rows =
        case cache_get(matchup_key(patch, civ_slug, path, map_id)) do
          {:ok, rows} -> rows
          :miss -> []
        end

      {path_key(path), rows}
    end)
  end

  defp prefetch_civ_matchups(civs, patch, map_id) do
    civs
    |> Task.async_stream(
      fn civ ->
        case fetch_civ_matchups_remote(civ, patch, map_id) do
          {:ok, rows} ->
            put_durable(civ_matchup_key(patch, civ, map_id), rows)
            :ok

          {:error, reason} ->
            Logger.warning("[AgeupsAPI] civ matchup prefetch failed for #{civ}: #{inspect(reason)}")
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

  defp fetch_civ_matchups_remote(civ_slug, patch, map_id) do
    params =
      %{"kind" => "rm_solo", "patch" => patch, "civilization" => civ_slug}
      |> maybe_put("map_id", map_id)

    url = "#{@base_url}/stats/analytics/ageups/matchups?" <> URI.encode_query(params)

    case get_json(url) do
      {:ok, %{"data" => data}} when is_list(data) -> {:ok, parse_matchups(data)}
      {:ok, _} -> {:ok, []}
      {:error, reason} -> {:error, reason}
    end
  end

  defp load_civ_matchups(civ_slug, patch, map_id) do
    case cache_get(civ_matchup_key(patch, civ_slug, map_id)) do
      {:ok, rows} ->
        rows

      :miss ->
        case fetch_civ_matchups_remote(civ_slug, patch, map_id) do
          {:ok, rows} ->
            put_durable(civ_matchup_key(patch, civ_slug, map_id), rows)
            rows

          _ ->
            []
        end
    end
  end

  defp civ_matchups_from_cache(civ_slug, patch, map_id) do
    case cache_get(civ_matchup_key(patch, civ_slug, map_id)) do
      {:ok, rows} -> rows
      :miss -> []
    end
  end

  defp civ_matchup_for(rows, opponent) do
    Enum.find(List.wrap(rows), &(&1.opponent == opponent))
  end

  defp civ_matchup_key(patch, civ_slug, map_id) do
    base = "ageups_civmu_#{patch}_#{civ_slug}"
    if map_id, do: "#{base}_#{map_id}", else: base
  end

  defp warm_map_combos(_patch, [], _opts), do: 0

  defp warm_map_combos(patch, maps, opts) do
    prefetch? = Keyword.get(opts, :prefetch_matchups, false)

    Enum.reduce(maps, 0, fn map, acc ->
      if is_nil(map_ref(map)) do
        acc
      else
        by_civ = fetch_map_paths(patch, map, opts)

        if prefetch? do
          prefetch_civ_matchups(Map.keys(by_civ), patch, map_ref(map))
          prefetch_matchups(by_civ, patch, map_ref(map))
        end

        cache_recommendations(by_civ, patch, map_ref(map))

        acc + map_size(by_civ)
      end
    end)
  end

  defp fetch_map_paths(patch, map, opts) do
    payloads = Keyword.get(opts, :map_payloads)
    civs = Wololo.Civilizations.slugs()

    Enum.reduce(civs, %{}, fn civ, acc ->
      case map_paths_for(civ, map, patch, payloads) do
        {:ok, paths} ->
          put_durable(paths_key(patch, civ, map_ref(map)), paths)
          Map.put(acc, civ, paths)

        {:error, reason} ->
          Logger.warning(
            "[AgeupsAPI] map path fetch failed for #{civ} on #{map.name}: #{inspect(reason)}"
          )

          acc
      end
    end)
  end

  defp map_paths_for(civ, map, _patch, %{} = payloads) do
    payload = Map.get(payloads, map_ref(map)) || Map.get(payloads, map.name)
    {:ok, if(payload, do: parse_paths(payload, civ), else: [])}
  end

  defp map_paths_for(civ, map, patch, _payloads) do
    case fetch_ageups_remote(patch, civilization: civ, map_id: map.id) do
      {:ok, payload} -> {:ok, parse_paths(payload, civ)}
      error -> error
    end
  end

  defp current_season_maps do
    case Wololo.MapPool.refresh() do
      {:ok, %{maps: maps}} ->
        Enum.filter(maps, &(not is_nil(map_ref(&1))))

      _ ->
        []
    end
  end

  defp map_ref(%{id: id}) when not is_nil(id), do: id
  defp map_ref(_), do: nil

  defp matchup_limit(nil), do: @max_matchup_candidates
  defp matchup_limit(_map_id), do: @max_map_matchup_candidates

  defp maybe_put(params, _key, nil), do: params
  defp maybe_put(params, _key, ""), do: params
  defp maybe_put(params, key, value), do: Map.put(params, key, value)

  defp paths_key(patch, civ_slug, map_id \\ nil) do
    base = "ageups_paths_#{patch}_#{civ_slug}"
    if map_id, do: "#{base}_#{map_id}", else: base
  end

  defp matchup_key(patch, civ_slug, path, map_id) do
    base = "ageups_mu_#{patch}_#{civ_slug}_#{path.age2.pbgid}_#{path.age3.pbgid}_#{path.age4.pbgid}"
    if map_id, do: "#{base}_#{map_id}", else: base
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
