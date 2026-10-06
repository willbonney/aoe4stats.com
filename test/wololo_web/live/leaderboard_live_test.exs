defmodule WololoWeb.LeaderboardLiveTest do
  use WololoWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  setup do
    players =
      for rank <- 1..10 do
        %{rank: rank, name: "US#{rank}", profile_id: "#{rank}", rating: 1500, country: "us"}
      end ++
        [
          %{rank: 11, name: "Edge", profile_id: "11", rating: 1400, country: "us"},
          %{rank: nil, name: "Unranked", profile_id: "12", rating: 1800, country: "us"},
          %{rank: 13, name: "Almost", profile_id: "13", rating: 1399, country: "de"},
          %{rank: 14, name: "High", profile_id: "14", rating: 1999, country: "de"},
          %{rank: 15, name: "Top", profile_id: "15", rating: 2000, country: "fr"}
        ]

    Cachex.put(:wololo_cache, :leaderboard_data, players)
    Cachex.put(:wololo_cache, :leaderboard_last_updated, ~U[2026-04-01 12:00:00Z])

    on_exit(fn ->
      Cachex.del(:wololo_cache, :leaderboard_data)
      Cachex.del(:wololo_cache, :leaderboard_last_updated)
    end)

    :ok
  end

  test "counts 1400 as conqueror and keeps 2000+ on its own tab", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/leaderboard")
    html = if html =~ "Total Players", do: html, else: render(view)

    assert html =~ "players rated 1400 or above"
    assert html =~ "United States"
    assert html =~ "85.71%"
    refute html =~ "Error Loading Data"

    conq3 = view |> element("button[phx-value-tab='conqueror3']") |> render_click()
    assert conq3 =~ "2000 or above"
    assert conq3 =~ "France"
    refute conq3 =~ "Germany"
    refute conq3 =~ "United States"

    per_capita = view |> element("button[phx-value-tab='per_capita']") |> render_click()
    assert per_capita =~ "0.04"

    avg = view |> element("button[phx-value-tab='avg_rank']") |> render_click()
    assert avg =~ "11 players"

    prowess = view |> element("button[phx-value-tab='prowess']") |> render_click()
    assert prowess =~ "National Prowess"
    refute prowess =~ "Error Loading Data"
  end
end
