defmodule WololoWeb.SEO do
  @moduledoc """
  Site-wide titles, descriptions, canonical URLs, and JSON-LD for search engines.
  """

  import Phoenix.Component, only: [assign: 2]

  @site_name "AoE4 Stats"
  @canonical_host "aoe4stats.com"
  @default_title "AoE4 Stats · Age of Empires 4 Win Rates & Player Statistics"
  @default_description "In-depth Age of Empires 4 statistics: civilization win rates by map and league, landmark age-up paths, player rating analysis, and 1v1 leaderboard breakdowns."
  @og_image_path "/images/og.jpg"

  @type meta :: %{
          title: String.t(),
          description: String.t(),
          path: String.t(),
          breadcrumbs: [{String.t(), String.t()}]
        }

  def site_name, do: @site_name
  def canonical_host, do: @canonical_host
  def default_title, do: @default_title
  def default_description, do: @default_description

  def site_url, do: "https://#{@canonical_host}"

  def og_image_url, do: site_url() <> @og_image_path

  def canonical_url(path) when is_binary(path) do
    path = if String.starts_with?(path, "/"), do: path, else: "/" <> path
    site_url() <> path
  end

  def canonical_url(_), do: site_url() <> "/"

  @doc """
  Assigns default SEO for the current LiveView. Player pages override via `assign_player/1`.
  """
  def assign_defaults(socket) do
    meta = meta_for(socket.view)

    assign(socket,
      page_title: meta.title,
      page_description: meta.description,
      canonical_url: canonical_url(meta.path),
      og_image_url: og_image_url(),
      seo_breadcrumbs: meta.breadcrumbs,
      seo_player_name: nil
    )
  end

  @doc """
  Sets the canonical URL from the request path (query string stripped).
  """
  def assign_canonical_from_uri(socket, uri) when is_binary(uri) do
    path = uri |> URI.parse() |> Map.get(:path) || "/"
    assign(socket, canonical_url: canonical_url(path))
  end

  def assign_canonical_from_uri(socket, _), do: socket

  @doc """
  Unique title, description, and canonical for a player (and optional section).
  """
  def assign_player(socket) do
    profile_id = socket.assigns[:profile_id]

    if is_nil(profile_id) or profile_id == "" do
      meta = meta_for(WololoWeb.PlayerLive)
      assign_canonical = canonical_url(meta.path)

      assign(socket,
        page_title: meta.title,
        page_description: meta.description,
        canonical_url: assign_canonical,
        seo_breadcrumbs: meta.breadcrumbs,
        seo_player_name: nil
      )
    else
      name = socket.assigns[:name]
      section = socket.assigns[:active] || :rating
      meta = player_meta(name, profile_id, section)

      assign(socket,
        page_title: meta.title,
        page_description: meta.description,
        canonical_url: canonical_url(meta.path),
        seo_breadcrumbs: meta.breadcrumbs,
        seo_player_name: name
      )
    end
  end

  def player_meta(name, profile_id, section) do
    display = display_name(name)
    profile_id = to_string(profile_id)

    {title, description, path, crumb} =
      case section do
        :rank ->
          {
            "#{display} Rank History · AoE4 Stats",
            "#{possessive(display)} Age of Empires 4 season-end rank history on the 1v1 ranked ladder.",
            "/player/#{profile_id}/rank",
            "Rank"
          }

        :analysis ->
          {
            "#{display} Analysis · AoE4 Stats",
            "#{possessive(display)} Age of Empires 4 skill analysis: peak proximity, recovery, momentum, anti-tilt, and more.",
            "/player/#{profile_id}/analysis",
            "Analysis"
          }

        :game_length ->
          {
            "#{display} Game Length · AoE4 Stats",
            "#{possessive(display)} Age of Empires 4 win rates by game length, from early Feudal fights to late Imperial.",
            "/player/#{profile_id}/game_length",
            "Game Length"
          }

        :opponents ->
          {
            "#{display} Opponents · AoE4 Stats",
            "Where #{possessive(display)} Age of Empires 4 ranked opponents come from, mapped by country.",
            "/player/#{profile_id}/opponents",
            "Opponents"
          }

        :insights ->
          {
            "#{display} Insights · AoE4 Stats",
            "AI-written insights on #{possessive(display)} Age of Empires 4 1v1 trends, civs, and performance patterns.",
            "/player/#{profile_id}/insights",
            "Insights"
          }

        :rating ->
          rating_meta(display, profile_id)

        _ ->
          rating_meta(display, profile_id)
      end

    %{
      title: title,
      description: description,
      path: path,
      breadcrumbs: [
        {"Home", "/"},
        {display, "/player/#{profile_id}"},
        {crumb, path}
      ]
    }
  end

  defp rating_meta(display, profile_id) do
    {
      "#{display} · AoE4 Stats",
      "#{possessive(display)} Age of Empires 4 1v1 stats: rating history, rank, analysis, game length, and opponents.",
      "/player/#{profile_id}",
      "Rating"
    }
  end

  def json_ld(assigns) do
    canonical = assigns[:canonical_url] || site_url() <> "/"
    title = assigns[:page_title] || @default_title
    description = assigns[:page_description] || @default_description
    breadcrumbs = assigns[:seo_breadcrumbs] || [{"Home", "/"}]
    player_name = assigns[:seo_player_name]

    webpage_type = if player_name, do: "ProfilePage", else: "WebPage"

    webpage = %{
      "@type" => webpage_type,
      "@id" => canonical <> "#webpage",
      "url" => canonical,
      "name" => title,
      "description" => description,
      "isPartOf" => %{"@id" => site_url() <> "/#website"},
      "inLanguage" => "en"
    }

    webpage =
      if player_name do
        Map.put(webpage, "mainEntity", %{
          "@type" => "Person",
          "name" => player_name,
          "url" => canonical
        })
      else
        webpage
      end

    graph = [
      %{
        "@type" => "WebSite",
        "@id" => site_url() <> "/#website",
        "name" => @site_name,
        "alternateName" => ["AOE4 Stats", "Age of Empires 4 Stats", "aoe4stats"],
        "url" => site_url(),
        "description" => @default_description,
        "inLanguage" => "en"
      },
      webpage,
      breadcrumb_list(breadcrumbs)
    ]

    Jason.encode!(%{"@context" => "https://schema.org", "@graph" => graph}, escape: :html_safe)
  end

  def meta_for(WololoWeb.HomeLive) do
    %{
      title: @default_title,
      description: @default_description,
      path: "/",
      breadcrumbs: [{"Home", "/"}]
    }
  end

  def meta_for(WololoWeb.CivsByMapLive) do
    %{
      title: "AoE4 Civilization Win Rates by Map",
      description:
        "Age of Empires 4 civilization win rates on every ranked 1v1 map, broken down by league from Bronze to Conqueror.",
      path: "/civs_by_map",
      breadcrumbs: [{"Home", "/"}, {"Civilization Win Rates by Map", "/civs_by_map"}]
    }
  end

  def meta_for(WololoWeb.CivsByLeagueLive) do
    %{
      title: "AoE4 Civilization Win Rates by League",
      description:
        "Compare Age of Empires 4 civilization win rates across Bronze, Silver, Gold, Platinum, Diamond, and Conqueror.",
      path: "/civs_by_league",
      breadcrumbs: [{"Home", "/"}, {"Civilization Win Rates by League", "/civs_by_league"}]
    }
  end

  def meta_for(WololoWeb.CivsMetaLive) do
    %{
      title: "AoE4 Civ Pick Rate vs Win Rate",
      description:
        "See which Age of Empires 4 civilizations are sleepers or traps by plotting pick rate against win rate for each league.",
      path: "/meta",
      breadcrumbs: [{"Home", "/"}, {"Pick Rate vs Win Rate", "/meta"}]
    }
  end

  def meta_for(WololoWeb.LandmarksLive) do
    %{
      title: "AoE4 Landmark Path Win Rates",
      description:
        "Best Age of Empires 4 landmark age-up paths by civilization, map, and matchup, based on ranked 1v1 win rates.",
      path: "/landmarks",
      breadcrumbs: [{"Home", "/"}, {"Landmark Path", "/landmarks"}]
    }
  end

  def meta_for(WololoWeb.LeaderboardLive) do
    %{
      title: "AoE4 Leaderboard by Country",
      description:
        "Age of Empires 4 1v1 leaderboard by country: Conqueror counts, per-capita rates, average rank, and national prowess.",
      path: "/leaderboard",
      breadcrumbs: [{"Home", "/"}, {"Leaderboard", "/leaderboard"}]
    }
  end

  def meta_for(WololoWeb.PlayerLive) do
    %{
      title: "AoE4 Player Stats",
      description:
        "Look up Age of Empires 4 1v1 player stats: rating history, rank, skill analysis, game length, and opponents.",
      path: "/player",
      breadcrumbs: [{"Home", "/"}, {"Player Stats", "/player"}]
    }
  end

  def meta_for(_view) do
    %{
      title: @default_title,
      description: @default_description,
      path: "/",
      breadcrumbs: [{"Home", "/"}]
    }
  end

  defp breadcrumb_list(crumbs) do
    items =
      crumbs
      |> Enum.with_index(1)
      |> Enum.map(fn {{name, path}, i} ->
        %{
          "@type" => "ListItem",
          "position" => i,
          "name" => name,
          "item" => canonical_url(path)
        }
      end)

    %{
      "@type" => "BreadcrumbList",
      "itemListElement" => items
    }
  end

  defp display_name(nil), do: "AoE4 Player"
  defp display_name(""), do: "AoE4 Player"

  defp display_name(name) when is_binary(name) do
    if String.length(name) > 32, do: String.slice(name, 0, 32) <> "…", else: name
  end

  defp display_name(_), do: "AoE4 Player"

  defp possessive("AoE4 Player"), do: "This player's"

  defp possessive(name) do
    if String.ends_with?(name, "s"), do: "#{name}'", else: "#{name}'s"
  end
end
