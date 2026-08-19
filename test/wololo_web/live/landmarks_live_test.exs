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

  test "result loader warns that the first load can take up to a minute" do
    html = File.read!("lib/wololo_web/live/landmarks_live.html.heex")
    assert html =~ "Finding the strongest path..."
    assert html =~ "First load can take 30–60 seconds to complete."
    assert html =~ "disabled={pills_locked?}"
    assert html =~ "pills_locked? = @loading or @loading_matchups"
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
    assert html =~ "Skip — Any Civ"
    refute html =~ "anyone"
    assert html =~ "on"
    assert html =~ "any map"

    html =
      view
      |> element("button[phx-click='skip-opponent']")
      |> render_click()

    assert html =~ "Recommended path"
    refute has_element?(view, "button[phx-value-menu='civ'][disabled]")
    refute has_element?(view, "button[phx-value-menu='map'][disabled]")
    refute has_element?(view, "button[phx-value-menu='opponent'][disabled]")
    refute has_element?(view, "button[phx-value-menu='ages'][disabled]")
    assert html =~ "Age IV"
    assert html =~ "School of Cavalry"
    assert html =~ "Guild Hall"
    assert html =~ "Red Palace"
    assert html =~ "Any Civ"
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
    assert html =~ "61.00%"
    assert html =~ "This exact combo"
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

  test "pills are disabled while finding the strongest path", %{conn: conn} do
    html =
      conn
      |> get("/landmarks?civ=french&map=any&opponent=english&step=result")
      |> html_response(200)

    assert html =~ "Finding the strongest path"
    assert html =~ ~r/phx-value-menu="civ"[^>]*disabled/
    assert html =~ ~r/phx-value-menu="map"[^>]*disabled/
    assert html =~ ~r/phx-value-menu="opponent"[^>]*disabled/
    assert html =~ ~r/phx-value-menu="ages"[^>]*disabled/
  end

  test "ages pill switches to a 1-2 path without leaving the result", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/landmarks")

    view |> element("button[phx-value-civ='french']") |> render_click()
    view |> element("#any-map") |> render_click()
    view |> element("button[phx-click='skip-opponent']") |> render_click()
    assert render(view) =~ "Red Palace"

    view |> element("button[phx-click='toggle-menu'][phx-value-menu='ages']") |> render_click()

    html =
      view
      |> element("button[phx-click='change-ages'][phx-value-ages='1-2']")
      |> render_click()

    assert html =~ "School of Cavalry"
    refute html =~ "Guild Hall"
    refute html =~ "Red Palace"
    assert html =~ "Age II"
    refute html =~ "Age III"
    assert_patch(view, "/landmarks?ages=1-2&civ=french&map=any&opponent=any&step=result")
  end

  test "pill dropdown changes civ without leaving the result", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/landmarks")

    view |> element("button[phx-value-civ='french']") |> render_click()
    view |> element("#any-map") |> render_click()
    view |> element("button[phx-click='skip-opponent']") |> render_click()
    assert render(view) =~ "Recommended path"

    view |> element("button[phx-click='toggle-menu'][phx-value-menu='civ']") |> render_click()

    html =
      view
      |> element("button[phx-click='change-civ'][phx-value-civ='english']")
      |> render_click()

    refute html =~ "Which civ are you playing?"
    assert html =~ "English"
    assert html =~ "Any Civ"
    assert html =~ "Finding the strongest path" or html =~ "Recommended path"
    assert_patch(view, "/landmarks?civ=english&map=any&opponent=any&step=result")
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

  test "result_stats leads with the exact combo then the any-map build WR" do
    civ = %{label: "Delhi", slug: "delhi_sultanate", key: :delhi_sultanate}
    opp = %{label: "French", slug: "french", key: :french}
    map = %{name: "Dry Arabia", any?: false, id: 163361}

    rec = %{
      path: %{win_rate: 66.0, games: 400},
      matchup: %{win_rate: 78.57, games: 42},
      any_map_matchup: %{win_rate: 61.2, games: 180}
    }

    [exact, any_map] = WololoWeb.LandmarksLive.result_stats(civ, map, opp, rec)

    assert exact.title == "This exact combo"
    assert exact.wr == 78.57
    assert exact.detail =~ "French"
    assert exact.detail =~ "Dry Arabia"
    assert any_map.title == "This build vs French"
    assert any_map.detail == "any map"
    assert any_map.wr == 61.2

    [any_civ] = WololoWeb.LandmarksLive.result_stats(civ, map, nil, rec)
    assert any_civ.detail == "on Dry Arabia · Any Civ"
    refute any_civ.detail =~ "anyone"
    refute any_civ.detail =~ "any opponent"
  end

  test "path_landmarks drops ages the selected span does not include" do
    path = %{
      age2: %{name: "School of Cavalry"},
      age3: nil,
      age4: nil
    }

    assert [{%{name: "School of Cavalry"}, "Age II"}] = WololoWeb.LandmarksLive.path_landmarks(path)
    assert WololoWeb.LandmarksLive.through_range_label(2) == "Age II"
    assert WololoWeb.LandmarksLive.through_range_label(3) == "Age III"
    assert WololoWeb.LandmarksLive.through_choice(4).label == "Age IV"
    assert WololoWeb.LandmarksLive.through_choice(4).slug == "1-4"
  end
end
