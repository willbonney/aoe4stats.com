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
end
