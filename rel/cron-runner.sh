#!/bin/bash
set -e

/app/bin/wololo eval "$(cat /app/rel/cron_job.exs)"
