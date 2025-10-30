# This script ensures all applications are started before running the cron job
Application.ensure_all_started(:hackney)
Application.ensure_all_started(:httpoison)
Application.ensure_all_started(:floki)
Application.ensure_all_started(:cachex)

# Create/start the cache if it doesn't exist
# Try start_link first (for supervisor context), then start (for standalone)
cache_result = case Cachex.start_link(:wololo_cache) do
  {:ok, _pid} ->
    :ok
  {:error, {:already_started, _pid}} ->
    :ok
  _ ->
    # If start_link fails, try start instead (for eval context)
    case Cachex.start(:wololo_cache) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      error -> {:error, error}
    end
end

case cache_result do
  :ok -> :ok  # Cache started successfully
  error ->
    IO.puts("Warning: Could not start cache: #{inspect(error)}")
    IO.puts("Continuing anyway - cache might be managed externally")
end

# Now run the job
Wololo.LeaderboardDumpCron.fetch_and_cache()
