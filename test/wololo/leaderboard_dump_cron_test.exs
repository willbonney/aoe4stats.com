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

    assert {:ok, vs_english} =
             AgeupsAPI.cached_recommendation("french", "english", AgeupsFixtures.patch())

    assert vs_english.path

    assert info.maps == 1

    assert {:ok, on_map} =
             AgeupsAPI.cached_recommendation(
               "french",
               nil,
               AgeupsFixtures.patch(),
               AgeupsFixtures.dry_arabia_id()
             )

    assert on_map.path.age2.name == "Chamber of Commerce"
  end

  test "crontab still hits every app machine so local Cachex stays warm" do
    crontab = File.read!(Path.expand("../../crontab", __DIR__))
    assert crontab =~ "refresh-leaderboard"
    assert crontab =~ "0 3 * * 0"
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

  test "aoe4world requests send a recognizable user-agent" do
    source = File.read!(Path.expand("../../lib/wololo/leaderboard_dump_cron.ex", __DIR__))
    assert source =~ "HTTPClient.user_agent()"
    assert Wololo.HTTPClient.user_agent() == "aoe4stats/1.0"
  end

  test "parse_csv keeps commas and escaped quotes inside names" do
    csv = """
    rank,name,profile_id,rating,games_count,wins_count,last_game_at,rank_level,country
    1,"Smith, Jr.",10,2100,100,60,2026-01-01,conqueror,us\r
    2,"Say ""Hi""",11,1400,10,5,2026-01-02,conqueror,de
    not,a,valid,row
    """

    assert {:ok, [first, second]} = LeaderboardDumpCron.parse_csv(csv)
    assert first.name == "Smith, Jr."
    assert first.profile_id == "10"
    assert first.rating == 2100
    assert first.country == "us"
    assert second.name == "Say \"Hi\""
    assert second.country == "de"
  end

  test "get_player and sitemap ids read the cached dump" do
    Cachex.put(:wololo_cache, :leaderboard_data, [
      %{profile_id: "10", name: "Smith", rank: 1},
      %{profile_id: "", name: "Blank", rank: 2},
      %{profile_id: nil, name: "Missing", rank: 3}
    ])

    assert {:ok, %{name: "Smith"}} = LeaderboardDumpCron.get_player(10)
    assert {:error, :not_found} = LeaderboardDumpCron.get_player("999")
    assert LeaderboardDumpCron.sitemap_profile_ids() == ["10"]
  end

  test "refresh_ageups returns the HTTP error when ageups is unreachable" do
    Application.put_env(:wololo, :http_client, Wololo.FakeHTTP.Failing)
    assert {:error, reason} = LeaderboardDumpCron.refresh_ageups()
    assert reason =~ "boom"
  end
end
