defmodule WololoWeb.SEOTest do
  use WololoWeb.ConnCase, async: false

  alias WololoWeb.SEO

  setup do
    Cachex.del(:wololo_cache, :leaderboard_data)
    :ok
  end

  test "home page includes indexable title, description, canonical, and Open Graph tags", %{
    conn: conn
  } do
    html = html_response(get(conn, ~p"/"), 200)

    assert html =~ "AoE4 Stats · Age of Empires 4 Win Rates &amp; Player Statistics"
    assert html =~ ~s(name="description")
    assert html =~ "civilization win rates by map and league"
    assert html =~ ~s(rel="canonical" href="https://aoe4stats.com/")
    assert html =~ ~s(property="og:title")
    assert html =~ ~s(property="og:image" content="https://aoe4stats.com/images/og.jpg")
    assert html =~ ~s(name="twitter:card" content="summary_large_image")
    assert html =~ ~s(type="application/ld+json")
    assert html =~ "schema.org"
    assert html =~ "WebSite"
    refute html =~ "Phoenix Framework"
    refute html =~ "Wololo ·"
  end

  test "tool pages have unique titles and canonical URLs", %{conn: conn} do
    html = html_response(get(conn, ~p"/civs_by_map"), 200)
    assert html =~ "AoE4 Civilization Win Rates by Map"
    assert html =~ ~s(href="https://aoe4stats.com/civs_by_map")
    assert html =~ "Civilization Win Rates by Map"

    html = html_response(get(conn, ~p"/landmarks"), 200)
    assert html =~ "AoE4 Landmark Path Win Rates"
    assert html =~ ~s(href="https://aoe4stats.com/landmarks")
  end

  test "player page title uses leaderboard cache on the first HTML response", %{conn: conn} do
    {:ok, true} =
      Cachex.put(:wololo_cache, :leaderboard_data, [
        %{
          rank: 1,
          name: "Beasty",
          profile_id: "1676400",
          rating: 2400,
          games_count: 100,
          wins_count: 60,
          last_game_at: "",
          rank_level: "conqueror_3",
          country: "ca"
        }
      ])

    html = html_response(get(conn, ~p"/player/1676400"), 200)
    assert html =~ "Beasty · AoE4 Stats"
    assert html =~ ~s(href="https://aoe4stats.com/player/1676400")
    assert html =~ "Beasty"
    assert html =~ "ProfilePage"
  end

  test "robots.txt allows crawlers and points at the sitemap", %{conn: conn} do
    body = text_response(get(conn, "/robots.txt"), 200)
    assert body =~ "User-agent: *"
    assert body =~ "Allow: /"
    assert body =~ "Disallow: /api/"
    assert body =~ "Sitemap: https://aoe4stats.com/sitemap.xml"
  end

  test "sitemap lists static routes and cached players", %{conn: conn} do
    {:ok, true} =
      Cachex.put(:wololo_cache, :leaderboard_data, [
        %{profile_id: "111", name: "Alice"},
        %{profile_id: "222", name: "Bob"}
      ])

    body = response(get(conn, "/sitemap.xml"), 200)

    assert body =~ ~s(<?xml version="1.0" encoding="UTF-8"?>)
    assert body =~ "<urlset"
    assert body =~ "<loc>https://aoe4stats.com/</loc>"
    assert body =~ "<loc>https://aoe4stats.com/civs_by_map</loc>"
    assert body =~ "<loc>https://aoe4stats.com/civs_by_league</loc>"
    assert body =~ "<loc>https://aoe4stats.com/meta</loc>"
    assert body =~ "<loc>https://aoe4stats.com/landmarks</loc>"
    assert body =~ "<loc>https://aoe4stats.com/leaderboard</loc>"
    assert body =~ "<loc>https://aoe4stats.com/player/111</loc>"
    assert body =~ "<loc>https://aoe4stats.com/player/222</loc>"
  end

  test "IndexNow key file is served at the site root", %{conn: conn} do
    assert text_response(get(conn, "/8f3c2a91e4b64c7d9a12f0e5c8b3d176.txt"), 200) ==
             "8f3c2a91e4b64c7d9a12f0e5c8b3d176"
  end

  test "www host is permanently redirected to the apex domain", %{conn: conn} do
    conn =
      conn
      |> Map.put(:host, "www.aoe4stats.com")
      |> get("/civs_by_map?league=gold")

    assert conn.status == 301

    assert Plug.Conn.get_resp_header(conn, "location") == [
             "https://aoe4stats.com/civs_by_map?league=gold"
           ]
  end

  test "alias hosts redirect to aoe4stats.com", %{conn: conn} do
    for host <- ["aoe4.win", "www.aoe4.win", "wololo.fly.dev"] do
      redirected =
        conn
        |> Map.put(:host, host)
        |> get("/leaderboard")

      assert redirected.status == 301

      assert Plug.Conn.get_resp_header(redirected, "location") == [
               "https://aoe4stats.com/leaderboard"
             ]
    end
  end

  test "trailing slashes redirect to the slashless path", %{conn: conn} do
    conn = get(conn, "/player/1676400/")
    assert conn.status == 301
    assert Plug.Conn.get_resp_header(conn, "location") == ["/player/1676400"]
  end

  test "crawlers can fetch favicon.ico and apple-touch-icon at the site root", %{conn: conn} do
    assert get(conn, "/favicon.ico").status == 200
    assert get(conn, "/apple-touch-icon.png").status == 200
    assert get(conn, "/apple-touch-icon-precomposed.png").status == 200
  end

  test "player_meta canonicalizes rating to the player root" do
    meta = SEO.player_meta("Beasty", "1676400", :rating)
    assert meta.path == "/player/1676400"
    assert meta.title == "Beasty · AoE4 Stats"

    meta = SEO.player_meta("Beasty", "1676400", :analysis)
    assert meta.path == "/player/1676400/analysis"
    assert meta.title =~ "Analysis"
  end
end
