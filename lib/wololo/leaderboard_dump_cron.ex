defmodule Wololo.LeaderboardDumpCron do
  @moduledoc """
  Fetches, processes, and caches the leaderboard dump from AoE4World.
  Runs as a scheduled cron job to keep leaderboard data fresh.
  """
  require Logger

  @leaderboard_url "https://aoe4world.com/api/v0/leaderboards/rm_solo/download"
  @cache_key :leaderboard_data

  def fetch_and_cache do
    Logger.info("[LeaderboardDumpCron] Starting leaderboard data refresh...")
    start_time = System.monotonic_time(:millisecond)

    case download_and_process() do
      {:ok, data} ->
        duration = System.monotonic_time(:millisecond) - start_time

        Logger.info(
          "[LeaderboardDumpCron] Successfully cached #{length(data)} leaderboard entries in #{duration}ms"
        )

        :ok

      {:error, reason} ->
        Logger.error(
          "[LeaderboardDumpCron] Failed to refresh leaderboard data: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  defp download_and_process do
    with {:download, {:ok, zip_data}} <- {:download, download_zip()},
         {:unzip, {:ok, csv_content}} <- {:unzip, unzip_file(zip_data)},
         {:parse, {:ok, parsed_data}} <- {:parse, parse_csv(csv_content)},
         {:cache, {:ok, true}} <- {:cache, cache_data(parsed_data)} do
      {:ok, parsed_data}
    else
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

  defp download_zip do
    Logger.info("[LeaderboardDumpCron] Downloading leaderboard zip from #{@leaderboard_url}")

    case HTTPoison.get(@leaderboard_url, [], timeout: 60_000, recv_timeout: 60_000) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        Logger.info("[LeaderboardDumpCron] Downloaded #{byte_size(body)} bytes")
        {:ok, body}

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:error, "HTTP #{status_code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  defp unzip_file(zip_data) do
    Logger.info("[LeaderboardDumpCron] Unzipping file...")

    case :zip.unzip(zip_data, [:memory]) do
      {:ok, files} ->
        # Find the CSV file (should be the first/only file in the archive)
        case Enum.find(files, fn {filename, _content} ->
               String.ends_with?(to_string(filename), ".csv")
             end) do
          {_filename, content} ->
            Logger.info("[LeaderboardDumpCron] Extracted CSV file (#{byte_size(content)} bytes)")
            {:ok, content}

          nil ->
            {:error, "No CSV file found in zip"}
        end

      {:error, reason} ->
        {:error, reason}
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
    # Parse CSV row - adjust fields based on actual CSV structure
    # This is a placeholder - you'll need to adjust based on the actual CSV format
    case String.split(line, ",") do
      [profile_id, name, rank, rating | _rest] ->
        %{
          profile_id: String.trim(profile_id),
          name: String.trim(name),
          rank: String.to_integer(String.trim(rank)),
          rating: String.to_integer(String.trim(rating))
        }

      _ ->
        nil
    end
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

  @doc """
  Retrieves the cached leaderboard data.
  Returns {:ok, data} if available, {:error, :not_found} otherwise.
  """
  def get_cached_data do
    case Cachex.get(:wololo_cache, @cache_key) do
      {:ok, nil} -> {:error, :not_found}
      {:ok, data} -> {:ok, data}
      error -> error
    end
  end

  @doc """
  Returns the last update timestamp for the leaderboard data.
  """
  def last_updated do
    case Cachex.get(:wololo_cache, :leaderboard_last_updated) do
      {:ok, nil} -> {:error, :not_found}
      {:ok, timestamp} -> {:ok, timestamp}
      error -> error
    end
  end
end
