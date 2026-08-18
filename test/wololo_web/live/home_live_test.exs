defmodule WololoWeb.HomeLiveTest do
  use WololoWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  setup do
    Cachex.del(:wololo_cache, "fly_monthly_cost")

    on_exit(fn ->
      Cachex.del(:wololo_cache, "fly_monthly_cost")
    end)

    :ok
  end

  test "hides hosting cost when none is cached", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")
    refute html =~ "This site costs about"
    refute html =~ "$25/mo"
  end

  test "shows cached monthly hosting cost on the home page and nav", %{conn: conn} do
    Cachex.put(:wololo_cache, "fly_monthly_cost", %{
      amount: 24.63,
      label: "$25",
      tooltip: "About $24.63/month"
    })

    {:ok, view, _html} = live(conn, ~p"/")

    assert render(view) =~ "This site costs about $25/month to host."
    assert render(view) =~ "$25/mo"
  end
end
