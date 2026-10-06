defmodule Wololo.ApplicationTest do
  use ExUnit.Case, async: false

  setup do
    Cachex.clear(:wololo_cache)
    on_exit(fn -> Cachex.clear(:wololo_cache) end)
    :ok
  end

  test "boot refresh follows the leaderboard cache, not an unused key" do
    assert Wololo.Application.cache_refresh_plan() == :leaderboard

    Cachex.put(:wololo_cache, "leaderboard_players", [%{profile_id: "1"}])
    assert Wololo.Application.cache_refresh_plan() == :leaderboard

    Cachex.put(:wololo_cache, :leaderboard_data, [%{profile_id: "1"}])
    assert Wololo.Application.cache_refresh_plan() == :ageups

    Cachex.put(:wololo_cache, "ageups_options", {:ok, %{patch: "1"}})
    assert Wololo.Application.cache_refresh_plan() == :ready
  end
end
