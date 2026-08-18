defmodule WololoWeb.HomeLiveTest do
  use WololoWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  test "renders the home page without a hosting cost", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")
    assert html =~ "AOE4 Stats"
    assert html =~ "Landmark Path"
    refute html =~ "This site costs about"
    refute html =~ "$25/mo"
  end
end
