defmodule Wololo.LeaderboardDumpCron do
  @moduledoc """
  Fetches, processes, and caches the leaderboard dump from AoE4World.
  Runs as a scheduled cron job to keep leaderboard data fresh.
  """
  require Logger

  @dumps_page_url "https://aoe4world.com/dumps"
  @cache_key :leaderboard_data

  def fetch_and_cache do
    Task.start(fn ->
      case Wololo.MapPool.refresh() do
        {:ok, %{maps: maps}} ->
          Logger.info("[LeaderboardDumpCron] Refreshed RM solo map pool (#{length(maps)} maps)")

        {:error, reason} ->
          Logger.error("[LeaderboardDumpCron] Failed to refresh map pool: #{inspect(reason)}")
      end
    end)

    Task.start(fn ->
      Wololo.MapPool.refresh()
      refresh_ageups()
    end)

    Logger.info("[LeaderboardDumpCron] Starting leaderboard data refresh...")
    start_time = System.monotonic_time(:millisecond)

    case download_and_process() do
      {:ok, data} ->
        duration = System.monotonic_time(:millisecond) - start_time

        Logger.info(
          "[LeaderboardDumpCron] Successfully cached #{length(data)} leaderboard entries in #{duration}ms"
        )

        # Also refresh civs_by_league data in the background
        Task.start(fn ->
          Logger.info("[LeaderboardDumpCron] Refreshing civs_by_league cache...")
          case refresh_civs_by_league_cache() do
            {:ok, _data} ->
              Logger.info("[LeaderboardDumpCron] Successfully refreshed civs_by_league cache")
            {:error, reason} ->
              Logger.error("[LeaderboardDumpCron] Failed to refresh civs_by_league: #{inspect(reason)}")
          end
        end)

        :ok

      {:error, reason} ->
        Logger.error(
          "[LeaderboardDumpCron] Failed to refresh leaderboard data: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  defp download_and_process do
    with {:get_url, {:ok, download_url}} <- {:get_url, get_download_url()},
         {:download, {:ok, zip_data}} <- {:download, download_zip(download_url)},
         {:unzip, {:ok, csv_content}} <- {:unzip, unzip_file(zip_data)},
         {:parse, {:ok, parsed_data}} <- {:parse, parse_csv(csv_content)},
         {:cache, {:ok, true}} <- {:cache, cache_data(parsed_data)} do
      {:ok, parsed_data}
    else
      {:get_url, {:error, reason}} ->
        {:error, "Failed to get download URL: #{inspect(reason)}"}

      {:download, {:error, reason}} ->
        {:error, "Download failed: #{inspect(reason)}"}

      {:unzip, {:error, reason}} ->
        {:error, "Unzip failed: #{inspect(reason)}"}

      {:parse, {:error, reason}} ->
        {:error, "CSV parsing failed: #{inspect(reason)}"}

      {:cache, {:error, reason}} ->
        {:error, "Caching failed: #{inspect(reason)}"}
    end
  end

  defp get_download_url do
    Logger.info("[LeaderboardDumpCron] Fetching download link from #{@dumps_page_url}")

    case HTTPoison.get(@dumps_page_url, [], timeout: 30_000, recv_timeout: 30_000) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Floki.parse_document(body) do
          {:ok, document} ->
            # Find the link that starts with "Leaderboard - RM 1v1 - Elo"
            case Floki.find(document, "a") do
              [] ->
                {:error, "No links found on dumps page"}

              links ->
                result =
                  Enum.find_value(links, fn link ->
                    text = Floki.text(link) |> String.trim()

                    if String.starts_with?(text, "Leaderboard - RM Solo - Points") do
                      case Floki.attribute(link, "href") do
                        [href | _] -> {:ok, href}
                        _ -> nil
                      end
                    end
                  end)

                case result do
                  {:ok, url} ->
                    Logger.info("[LeaderboardDumpCron] Found download URL: #{url}")
                    {:ok, url}

                  nil ->
                    {:error, "Could not find 'Leaderboard - RM Solo - Points' link"}
                end
            end

          {:error, reason} ->
            {:error, "Failed to parse HTML: #{inspect(reason)}"}
        end

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:error, "HTTP #{status_code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  defp download_zip(url) do
    Logger.info("[LeaderboardDumpCron] Downloading leaderboard gzip from #{url}")

    case HTTPoison.get(url, [], timeout: 60_000, recv_timeout: 60_000) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        Logger.info("[LeaderboardDumpCron] Downloaded #{byte_size(body)} bytes")
        {:ok, body}

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:error, "HTTP #{status_code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  defp unzip_file(gzip_data) do
    Logger.info("[LeaderboardDumpCron] Decompressing gzip file...")

    try do
      csv_content = :zlib.gunzip(gzip_data)
      Logger.info("[LeaderboardDumpCron] Decompressed CSV file (#{byte_size(csv_content)} bytes)")
      {:ok, csv_content}
    rescue
      e ->
        Logger.error("[LeaderboardDumpCron] Gzip decompression failed: #{inspect(e)}")
        {:error, "Gzip decompression failed: #{inspect(e)}"}
    end
  end

  defp parse_csv(csv_content) do
    Logger.info("[LeaderboardDumpCron] Parsing CSV data...")

    try do
      # Parse CSV - assuming it has headers
      rows =
        csv_content
        |> String.split("\n", trim: true)
        |> Enum.drop(1)
        # Drop header row
        |> Enum.map(&parse_csv_row/1)
        |> Enum.reject(&is_nil/1)

      Logger.info("[LeaderboardDumpCron] Parsed #{length(rows)} rows")
      {:ok, rows}
    rescue
      error ->
        {:error, error}
    end
  end

  defp parse_csv_row(line) do
    # CSV format: rank,name,profile_id,rating,games_count,wins_count,last_game_at,rank_level,country
    # Use proper CSV parsing to handle quoted fields (names with commas)
    case parse_csv_line(line) do
      [
        rank,
        name,
        profile_id,
        rating,
        games_count,
        wins_count,
        last_game_at,
        rank_level,
        country | _rest
      ] ->
        %{
          rank: parse_integer(rank),
          name: String.trim(name),
          profile_id: String.trim(profile_id),
          rating: parse_integer(rating),
          games_count: parse_integer(games_count),
          wins_count: parse_integer(wins_count),
          last_game_at: String.trim(last_game_at),
          rank_level: String.trim(rank_level),
          country: String.trim(country)
        }

      _ ->
        nil
    end
  rescue
    _ -> nil
  end

  # Simple CSV parser that handles quoted fields
  defp parse_csv_line(line) do
    line
    |> String.graphemes()
    |> parse_csv_fields([], [], false)
  end

  defp parse_csv_fields([], fields, current_field, _in_quotes) do
    Enum.reverse([Enum.reverse(current_field) |> Enum.join() | fields])
  end

  defp parse_csv_fields([char | rest], fields, current_field, in_quotes) do
    case {char, in_quotes} do
      # Toggle quote state
      {"\"", _} ->
        parse_csv_fields(rest, fields, current_field, !in_quotes)

      # Comma outside quotes = field separator
      {",", false} ->
        parse_csv_fields(rest, [Enum.reverse(current_field) |> Enum.join() | fields], [], false)

      # Any other character = add to current field
      {c, _} ->
        parse_csv_fields(rest, fields, [c | current_field], in_quotes)
    end
  end

  defp parse_integer(str) do
    str
    |> String.trim()
    |> String.to_integer()
  rescue
    _ -> nil
  end

  defp cache_data(data) do
    Logger.info("[LeaderboardDumpCron] Caching #{length(data)} entries...")

    case Cachex.put(:wololo_cache, @cache_key, data) do
      {:ok, true} ->
        # Also store metadata about the update
        Cachex.put(:wololo_cache, :leaderboard_last_updated, DateTime.utc_now())
        {:ok, true}

      error ->
        {:error, error}
    end
  end

  def refresh_ageups do
    Logger.info("[LeaderboardDumpCron] Refreshing ageups / landmark cache...")

    case Wololo.AgeupsAPI.refresh_cache() do
      {:ok, info} = ok ->
        Logger.info(
          "[LeaderboardDumpCron] Ageups cache ready (#{info.civs} civs, #{info.matchups} matchup sets, #{info.recommendations} recommendations)"
        )

        ok

      {:error, reason} = error ->
        Logger.error("[LeaderboardDumpCron] Failed to refresh ageups: #{inspect(reason)}")
        error
    end
  end

  def get_cached_data do
    case Cachex.get(:wololo_cache, @cache_key) do
      {:ok, nil} -> {:error, :not_found}
      {:ok, data} -> {:ok, data}
      error -> error
    end
  end

  def last_updated do
    case Cachex.get(:wololo_cache, :leaderboard_last_updated) do
      {:ok, nil} -> {:error, :not_found}
      {:ok, timestamp} -> {:ok, timestamp}
      error -> error
    end
  end

  defp refresh_civs_by_league_cache do
    # Clear the cache to force a fresh fetch
    Cachex.del(:wololo_cache, "civs_by_league_all")
    Enum.each(["bronze", "silver", "gold", "platinum", "diamond", "conqueror"], fn league ->
      Cachex.del(:wololo_cache, "civs_by_league_#{league}")
    end)

    # Now fetch fresh data (which will be cached)
    Wololo.CivsByLeagueAPI.fetch_all_leagues()
  end
end
