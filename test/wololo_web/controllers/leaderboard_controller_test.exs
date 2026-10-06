defmodule WololoWeb.LeaderboardControllerTest do
  use WololoWeb.ConnCase, async: false

  setup do
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

  test "POST /api/internal/refresh-leaderboard starts the cron refresh", %{conn: conn} do
    parent = self()
    previous = Application.get_env(:wololo, :leaderboard_refresh)
    Application.put_env(:wololo, :leaderboard_refresh, fn -> send(parent, :refreshed) end)

    on_exit(fn ->
      if previous do
        Application.put_env(:wololo, :leaderboard_refresh, previous)
      else
        Application.delete_env(:wololo, :leaderboard_refresh)
      end
    end)

    conn = post(conn, ~p"/api/internal/refresh-leaderboard")
    assert json_response(conn, 200) == %{"status" => "refresh started"}
    assert_receive :refreshed, 1_000
  end

  test "GET /api/leaderboard is not found until the cron warms cache", %{conn: conn} do
    Cachex.del(:wololo_cache, :leaderboard_data)
    conn = get(conn, ~p"/api/leaderboard")
    assert json_response(conn, 404)["error"] =~ "not yet available"
  end

  test "GET /api/leaderboard returns cached rows", %{conn: conn} do
    Cachex.put(:wololo_cache, :leaderboard_data, [
      %{profile_id: "1", name: "Test", rating: 2000, rank: 1}
    ])

    Cachex.put(:wololo_cache, :leaderboard_last_updated, ~U[2026-01-01 00:00:00Z])

    conn = get(conn, ~p"/api/leaderboard")
    body = json_response(conn, 200)
    assert body["count"] == 1
    assert hd(body["data"])["name"] == "Test"
  end

  test "GET /api/leaderboard/:profile_id returns one cached player", %{conn: conn} do
    Cachex.put(:wololo_cache, :leaderboard_data, [
      %{profile_id: "42", name: "Beasty", rating: 1800, rank: 3}
    ])

    conn = get(conn, ~p"/api/leaderboard/42")
    assert json_response(conn, 200)["name"] == "Beasty"

    missing = get(build_conn(), ~p"/api/leaderboard/7")
    assert json_response(missing, 404)["error"] =~ "not found"
  end

  test "GET /api/leaderboard/search matches a substring and skips blank names", %{conn: conn} do
    Cachex.put(:wololo_cache, :leaderboard_data, [
      %{profile_id: "1", name: "Beastyqt", rating: 2000, rank: 1},
      %{profile_id: "2", name: nil, rating: 1500, rank: 2},
      %{profile_id: "3", name: "Other", rating: 1400, rank: 3}
    ])

    conn = get(conn, ~p"/api/leaderboard/search?name=beast")
    body = json_response(conn, 200)
    assert body["count"] == 1
    assert hd(body["results"])["profile_id"] == "1"
  end

  test "GET /api/leaderboard/search requires a name", %{conn: conn} do
    conn = get(conn, ~p"/api/leaderboard/search")
    assert json_response(conn, 400)["error"] =~ "Missing name"
  end
end
