defmodule WololoWeb.SitemapController do
  use WololoWeb, :controller

  @max_player_urls 50_000

  @static_urls [
    {"/", "weekly", "1.0"},
    {"/civs_by_map", "daily", "0.9"},
    {"/civs_by_league", "daily", "0.9"},
    {"/meta", "daily", "0.8"},
    {"/landmarks", "weekly", "0.8"},
    {"/leaderboard", "daily", "0.8"}
  ]

  @indexnow_key "8f3c2a91e4b64c7d9a12f0e5c8b3d176"

  def indexnow_key(conn, _params) do
    conn
    |> put_resp_content_type("text/plain")
    |> put_resp_header("cache-control", "public, max-age=86400")
    |> send_resp(200, @indexnow_key)
  end

  def index(conn, _params) do
    lastmod = lastmod()

    body =
      [
        ~s(<?xml version="1.0" encoding="UTF-8"?>\n),
        ~s(<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n),
        Enum.map(@static_urls, fn {path, changefreq, priority} ->
          url_entry(WololoWeb.SEO.canonical_url(path), lastmod, changefreq, priority)
        end),
        Enum.map(player_ids(), fn profile_id ->
          url_entry(
            WololoWeb.SEO.canonical_url("/player/#{profile_id}"),
            lastmod,
            "weekly",
            "0.5"
          )
        end),
        ~s(</urlset>\n)
      ]

    conn
    |> put_resp_content_type("application/xml")
    |> put_resp_header("cache-control", "public, max-age=3600")
    |> send_resp(200, body)
  end

  defp player_ids do
    Wololo.LeaderboardDumpCron.sitemap_profile_ids(@max_player_urls)
  end

  defp lastmod do
    case Wololo.LeaderboardDumpCron.last_updated() do
      {:ok, %DateTime{} = ts} -> DateTime.to_iso8601(ts)
      _ -> DateTime.utc_now() |> DateTime.to_iso8601()
    end
  end

  defp url_entry(loc, lastmod, changefreq, priority) do
    [
      "  <url>\n",
      "    <loc>",
      xml_escape(loc),
      "</loc>\n",
      "    <lastmod>",
      xml_escape(lastmod),
      "</lastmod>\n",
      "    <changefreq>",
      changefreq,
      "</changefreq>\n",
      "    <priority>",
      priority,
      "</priority>\n",
      "  </url>\n"
    ]
  end

  defp xml_escape(value) do
    value
    |> to_string()
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end
end
