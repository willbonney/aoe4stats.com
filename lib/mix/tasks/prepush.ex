defmodule Mix.Tasks.Prepush do
  @shortdoc "Run the optional critical-path test suite"
  @moduledoc """
  Runs the fast, high-value tests used by the optional pre-push hook.

      mix prepush
      mix prepush.install   # opt in: git config core.hooksPath .githooks

  Skip a single push with `SKIP_PREPUSH=1 git push`.
  """
  use Mix.Task

  @files [
    "test/wololo/ageups_api_test.exs",
    "test/wololo/leaderboard_dump_cron_test.exs",
    "test/wololo/release_scripts_test.exs",
    "test/wololo/civilizations_test.exs",
    "test/wololo/map_pool_test.exs",
    "test/wololo/civ_helpers_test.exs",
    "test/wololo/utils_test.exs",
    "test/wololo/civs_by_map_api_test.exs",
    "test/wololo/player_stats_api_test.exs",
    "test/wololo/player_games_api_test.exs",
    "test/wololo/country_populations_test.exs",
    "test/wololo/fly_cost_test.exs",
    "test/wololo/matchups_and_meta_test.exs",
    "test/wololo_web/live/landmarks_live_test.exs",
    "test/wololo_web/live/home_live_test.exs",
    "test/wololo_web/live/routes_smoke_test.exs",
    "test/wololo_web/controllers/leaderboard_controller_test.exs",
    "test/wololo_web/controllers/page_controller_test.exs"
  ]

  @impl true
  def run(args) do
    Mix.Task.run("test", @files ++ args)
  end

  def files, do: @files
end
