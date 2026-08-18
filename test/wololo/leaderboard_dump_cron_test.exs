defmodule Wololo.LeaderboardDumpCronTest do
  use ExUnit.Case, async: false

  alias Wololo.AgeupsAPI
  alias Wololo.AgeupsFixtures
  alias Wololo.LeaderboardDumpCron

  setup do
    Cachex.clear(:wololo_cache)
    previous = Application.get_env(:wololo, :http_client)
    Application.put_env(:wololo, :http_client, Wololo.FakeHTTP)

    on_exit(fn ->
      if previous do
        Application.put_env(:wololo, :http_client, previous)
      else
        Application.delete_env(:wololo, :http_client)
      end
    end)

    :ok
  end

  test "refresh_ageups warms landmark paths and recommendations from the HTTP client" do
    assert {:ok, info} = LeaderboardDumpCron.refresh_ageups()
    assert info.patch == AgeupsFixtures.patch()
    assert info.civs == 2
    assert info.matchups > 0
    assert info.recommendations > 0

    assert {:ok, rec} = AgeupsAPI.recommend_for("french", nil, AgeupsFixtures.patch())
    assert rec.path.age4.name == "Red Palace"
    assert {:ok, vs_english} = AgeupsAPI.cached_recommendation("french", "english", AgeupsFixtures.patch())
    assert vs_english.path
  end

  test "crontab still hits every app machine so local Cachex stays warm" do
    crontab = File.read!(Path.expand("../../crontab", __DIR__))
    assert crontab =~ "refresh-leaderboard"
    assert crontab =~ "3 * * *"
  end

  test "cron job eval script calls fetch_and_cache" do
    script = File.read!(Path.expand("../../rel/cron_job.exs", __DIR__))
    assert script =~ "Wololo.LeaderboardDumpCron.fetch_and_cache()"
  end

  test "fetch_and_cache also kicks off the ageups landmark refresh" do
    source = File.read!(Path.expand("../../lib/wololo/leaderboard_dump_cron.ex", __DIR__))
    assert source =~ "refresh_ageups()"
    assert source =~ "Wololo.AgeupsAPI.refresh_cache()"
  end

  test "refresh_ageups returns the HTTP error when ageups is unreachable" do
    Application.put_env(:wololo, :http_client, Wololo.FakeHTTP.Failing)
    assert {:error, reason} = LeaderboardDumpCron.refresh_ageups()
    assert reason =~ "boom"
  end
end
