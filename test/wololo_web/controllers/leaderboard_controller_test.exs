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
    conn = post(conn, ~p"/api/internal/refresh-leaderboard")
    assert json_response(conn, 200) == %{"status" => "refresh started"}
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
end

