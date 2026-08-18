defmodule WololoWeb.RoutesSmokeTest do
  use WololoWeb.ConnCase, async: true

  test "core pages render", %{conn: conn} do
    assert html_response(get(conn, ~p"/"), 200) =~ "AOE4 Stats"
    assert html_response(get(conn, ~p"/landmarks"), 200) =~ "Landmark Path"
    assert html_response(get(conn, ~p"/meta"), 200)
    assert html_response(get(conn, ~p"/civs_by_map"), 200)
    assert html_response(get(conn, ~p"/civs_by_league"), 200)
    assert html_response(get(conn, ~p"/leaderboard"), 200) =~ "Conqueror"
  end
end
