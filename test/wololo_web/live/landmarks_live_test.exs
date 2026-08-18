defmodule WololoWeb.LandmarksLiveTest do
  use WololoWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  alias Wololo.AgeupsAPI
  alias Wololo.AgeupsFixtures

  setup do
    Cachex.clear(:wololo_cache)

    Cachex.put(:wololo_cache, :rm_solo_mappool, %{
      fetched_at: DateTime.utc_now(),
      maps: [%{name: "Dry Arabia"}]
    })

    {:ok, _} = AgeupsAPI.warm_from_payload(AgeupsFixtures.options(), AgeupsFixtures.payload())
    :ok
  end

  test "renders the wizard stepper", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/landmarks")
    assert html =~ "Landmark Path"
    assert html =~ "Civ"
    assert html =~ "Map"
    assert html =~ "Opponent"
    assert html =~ "Which civ are you playing?"
  end

  test "home page links to the landmark wizard", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")
    assert html =~ ~p"/landmarks"
    assert html =~ "Landmark Path"
  end

  test "walks civ -> any map -> skip opponent and shows a cached path", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/landmarks")

    html =
      view
      |> element("button[phx-value-civ='french']")
      |> render_click()

    assert html =~ "Which map?"
    assert html =~ "Any map"
    assert html =~ "Dry Arabia"
    assert html =~ "French"

    html =
      view
      |> element("#any-map")
      |> render_click()

    assert html =~ "Who are you facing?"
    assert html =~ "on"
    assert html =~ "any map"

    html =
      view
      |> element("button[phx-click='skip-opponent']")
      |> render_click()

    assert html =~ "Recommended path"
    assert html =~ "School of Cavalry"
    assert html =~ "Guild Hall"
    assert html =~ "Red Palace"
    assert html =~ "anyone"
    assert html =~ "hero-arrow-right"
    refute html =~ "→"
  end

  test "uses a cached opponent-specific path when one exists", %{conn: conn} do
    paths = AgeupsAPI.parse_paths(AgeupsFixtures.payload(), "french")
    counter = Enum.find(paths, &(&1.age2.name == "Chamber of Commerce"))

    rec = %{
      path: counter,
      alternatives: [],
      matchup: %{opponent: "english", win_rate: 61.0, games: 80, wins: 49, duration_average: 1500},
      civ_matchup: %{opponent: "english", win_rate: 47.5, games: 800, wins: 380, duration_average: 1500}
    }

    Cachex.put(
      :wololo_cache,
      AgeupsAPI.rec_key(AgeupsFixtures.patch(), "french", "english"),
      {:ok, rec}
    )

    {:ok, view, _html} = live(conn, ~p"/landmarks")

    view |> element("button[phx-value-civ='french']") |> render_click()
    view |> element("button[phx-value-map='Dry Arabia']") |> render_click()

    html =
      view
      |> element("button[phx-value-civ='english']")
      |> render_click()

    assert html =~ "Chamber of Commerce"
    assert html =~ "Royal Institute"
    assert html =~ "English"
    assert html =~ "47.50%"
    assert html =~ "61.00%"
    assert html =~ "This build is"
    assert html =~ "on"
    assert html =~ "Dry Arabia"
    assert html =~ "vs"
  end

  test "uses the season-map recommendation when a map id is present", %{conn: conn} do
    Cachex.put(:wololo_cache, :rm_solo_mappool, %{
      fetched_at: DateTime.utc_now(),
      maps: [%{name: "Dry Arabia", id: AgeupsFixtures.dry_arabia_id()}]
    })

    {:ok, _} =
      AgeupsAPI.warm_from_payload(AgeupsFixtures.options(), AgeupsFixtures.payload(),
        maps: [%{name: "Dry Arabia", id: AgeupsFixtures.dry_arabia_id()}],
        map_payloads: %{AgeupsFixtures.dry_arabia_id() => AgeupsFixtures.map_payload()}
      )

    {:ok, view, _html} = live(conn, ~p"/landmarks")

    view |> element("button[phx-value-civ='french']") |> render_click()
    view |> element("button[phx-value-map='Dry Arabia']") |> render_click()

    html =
      view
      |> element("button[phx-click='skip-opponent']")
      |> render_click()

    assert html =~ "Chamber of Commerce"
    assert html =~ "Royal Institute"
    assert html =~ "on Dry Arabia"
    refute html =~ "not split by map"
  end

  test "each wizard step is in the URL so back can return one step", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/landmarks")

    view |> element("button[phx-value-civ='french']") |> render_click()
    assert_patch(view, "/landmarks?civ=french&step=map")
    assert render(view) =~ "Which map?"

    view |> element("#any-map") |> render_click()
    assert_patch(view, "/landmarks?civ=french&map=any&step=opponent")
    assert render(view) =~ "Who are you facing?"

    {:ok, _view, html} = live(conn, "/landmarks?civ=french&step=map")
    assert html =~ "Which map?"
    refute html =~ "Who are you facing?"

    {:ok, _view, html} = live(conn, ~p"/landmarks")
    assert html =~ "Which civ are you playing?"
    refute html =~ "Which map?"
  end

  test "start over returns to the civ picker", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/landmarks")

    view |> element("button[phx-value-civ='french']") |> render_click()
    view |> element("#any-map") |> render_click()

    html = view |> element("button[phx-click='start-over']") |> render_click()

    assert html =~ "Which civ are you playing?"
    refute html =~ "Recommended path"
    refute html =~ "Start over"
  end
end
