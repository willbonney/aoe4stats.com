# Leaderboard Dump Cron Job

This cron job downloads, processes, and caches the aoe4world leaderboard data dump daily.

## Setup

The cron job has been configured with the following files:

- **`crontab`** - Defines the schedule (daily at 3 AM UTC)
- **`lib/wololo/leaderboard_dump_cron.ex`** - Handles downloading, unzipping, parsing CSV, and caching
- **`lib/wololo_web/controllers/leaderboard_controller.ex`** - API endpoints to access cached data
- **`fly.toml`** - Process configuration
- **`Dockerfile`** - Installs Supercronic

## Deployment

### First Time Setup

1. Deploy the app with the new configuration:

```bash
fly deploy
```

2. Scale the processes (only 1 cron process needed):

```bash
fly scale count app=2 cron=1
```

### Verify Cron is Running

Check the cron process logs:

```bash
fly logs -a wololo --process cron
```

You should see Supercronic starting and the cron schedule being loaded.

## Manual Trigger

To manually trigger the leaderboard refresh (useful for testing):

```bash
fly ssh console -a wololo
```

Then in the console:

```elixir
bin/wololo eval "Wololo.LeaderboardDumpCron.fetch_and_cache()"
```

Or use IEx:

```bash
fly ssh console -a wololo -C "bin/wololo remote"
```

Then:

```elixir
Wololo.LeaderboardDumpCron.fetch_and_cache()
```

## API Endpoints

### Get Full Leaderboard

```bash
GET https://aoe4stats.com/api/leaderboard
```

## Cron Schedule

The job runs **daily at 3:00 AM UTC**.

To change the schedule, edit `crontab`:

```
# Format: minute hour day month weekday
0 3 * * *     # Daily at 3 AM UTC
0 */6 * * *   # Every 6 hours
0 0 * * 0     # Weekly on Sunday at midnight
```

After changing, redeploy:

```bash
fly deploy
```

## Monitoring

### Check Last Update Time

```bash
curl https://aoe4stats.com/api/leaderboard | jq '.last_updated'
```

### View Cron Logs

```bash
fly logs -a wololo --process cron --tail
```

### Check Cache Status

In IEx:

```elixir
Wololo.LeaderboardDumpCron.last_updated()
Wololo.LeaderboardDumpCron.get_cached_data() |> elem(1) |> length()
```

## Troubleshooting

### Cron not running

Check if the cron process is up:

```bash
fly status
```

Should show both `app` and `cron` processes.

### No data in cache

Check the cron logs for errors:

```bash
fly logs -a wololo --process cron
```

Common issues:

- Download timeout (increase timeout in code)
- CSV format changed (adjust parsing logic)
- Cache not initialized (restart app)

### High memory usage

If the leaderboard is very large, you may need to increase memory:

```bash
fly scale memory 2048 --process cron
```

## Development

To test locally:

```bash
iex -S mix
```

Then:

```elixir
Wololo.LeaderboardDumpCron.fetch_and_cache()
```

The data will be cached in the running application and available at:

- `http://localhost:4000/api/leaderboard`
- `http://localhost:4000/api/leaderboard/:profile_id`
