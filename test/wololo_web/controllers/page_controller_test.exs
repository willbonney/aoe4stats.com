defmodule WololoWeb.PageControllerTest do
  use WololoWeb.ConnCase

  test "GET /", %{conn: conn} do
    html = html_response(get(conn, ~p"/"), 200)
    assert html =~ "AOE4 Stats"
    assert html =~ "Landmark Path"
  end
end
