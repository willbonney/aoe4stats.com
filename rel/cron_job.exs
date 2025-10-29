# This script ensures all applications are started before running the cron job
Application.ensure_all_started(:hackney)
Application.ensure_all_started(:httpoison)
Application.ensure_all_started(:floki)
Application.ensure_all_started(:cachex)
Application.ensure_all_started(:wololo)

# Now run the job
Wololo.LeaderboardDumpCron.fetch_and_cache()
