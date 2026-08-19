defmodule WololoWeb.LandmarksLive do
  use WololoWeb, :live_view

  alias Wololo.AgeupsAPI
  alias Wololo.Civilizations
  alias Wololo.MapPool
  alias WololoWeb.CivHelpers
  import WololoWeb.Components.Spinner

  @through_choices [
    %{value: 2, slug: "1-2", label: "Age II"},
    %{value: 3, slug: "1-3", label: "Age III"},
    %{value: 4, slug: "1-4", label: "Age IV"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    socket =
      assign(socket,
        step: :civ,
        civs: Civilizations.all(),
        maps: map_choices(),
        selected_civ: nil,
        selected_map: nil,
        selected_opponent: nil,
        selected_through: 4,
        through_choices: @through_choices,
        patch: AgeupsAPI.fallback_patch(),
        patch_label: nil,
        paths: [],
        recommendation: nil,
        loading: true,
        loading_matchups: false,
        error: nil,
        last_updated: nil,
        paths_key: nil,
        open_menu: nil
      )

    if connected?(socket), do: send(self(), :load_options)
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_params(socket, params)}
  end

  @impl true
  def handle_info(:load_options, socket) do
    {:ok, %{patch: patch, patch_label: label}} = AgeupsAPI.fetch_options()

    last_updated =
      case AgeupsAPI.last_updated() do
        {:ok, ts} -> ts
        _ -> nil
      end

    {:noreply,
     socket
     |> assign(
       patch: patch,
       patch_label: label,
       last_updated: last_updated,
       loading: false,
       error: nil
     )
     |> maybe_load_paths()}
  end

  def handle_info({:fetch_paths, civ_slug}, socket) do
    if socket.assigns.selected_civ && socket.assigns.selected_civ.slug == civ_slug do
      case AgeupsAPI.fetch_paths(civ_slug, socket.assigns.patch, selected_map_id(socket)) do
        {:ok, paths} ->
          socket =
            socket
            |> assign(paths: paths, loading: false, error: nil)
            |> maybe_refresh_result()

          {:noreply, socket}

        {:error, reason} ->
          {:noreply,
           assign(socket,
             paths: [],
             loading: false,
             error: "Failed to load landmark stats: #{reason}"
           )}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_info({:load_recommendation, opponent, through}, socket) do
    civ = socket.assigns.selected_civ
    same_opp = opponent_slug(socket.assigns.selected_opponent) == opponent
    same_through = socket.assigns.selected_through == through

    if civ && same_opp && same_through do
      case AgeupsAPI.recommend_for(
             civ.slug,
             opponent,
             socket.assigns.patch,
             selected_map_id(socket),
             through
           ) do
        {:ok, rec} ->
          {:noreply,
           socket
           |> assign(recommendation: rec, loading_matchups: false, error: nil)
           |> maybe_fill_any_map_matchup()}

        {:error, reason} ->
          {:noreply,
           assign(socket,
             loading_matchups: false,
             error: "Failed to load landmark path: #{reason}"
           )}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("select-civ", %{"civ" => slug}, socket) do
    {:noreply, push_patch(socket, to: wizard_path(%{"step" => "map", "civ" => slug}))}
  end

  def handle_event("select-map", params, socket) do
    map = if params["map"] in [nil, ""], do: "any", else: params["map"]

    {:noreply,
     push_patch(socket,
       to:
         wizard_path(%{
           "step" => "opponent",
           "civ" => civ_slug(socket.assigns.selected_civ),
           "map" => map
         })
     )}
  end

  def handle_event("select-opponent", %{"civ" => slug}, socket) do
    {:noreply, push_patch(socket, to: result_path(socket, slug))}
  end

  def handle_event("skip-opponent", _params, socket) do
    {:noreply, push_patch(socket, to: result_path(socket, "any"))}
  end

  def handle_event("toggle-menu", %{"menu" => menu}, socket) do
    if pills_locked?(socket) do
      {:noreply, assign(socket, open_menu: nil)}
    else
      open =
        case menu do
          "civ" -> :civ
          "map" -> :map
          "opponent" -> :opponent
          "ages" -> :ages
          _ -> nil
        end

      {:noreply, assign(socket, open_menu: if(socket.assigns.open_menu == open, do: nil, else: open))}
    end
  end

  def handle_event("close-menu", _params, socket) do
    {:noreply, assign(socket, open_menu: nil)}
  end

  def handle_event("change-civ", %{"civ" => slug}, socket) do
    {:noreply, push_patch(socket, to: retain_path(socket, %{"civ" => slug}))}
  end

  def handle_event("change-map", params, socket) do
    map = if params["map"] in [nil, ""], do: "any", else: params["map"]
    {:noreply, push_patch(socket, to: retain_path(socket, %{"map" => map}))}
  end

  def handle_event("change-opponent", %{"civ" => slug}, socket) do
    {:noreply, push_patch(socket, to: retain_path(socket, %{"opponent" => slug}))}
  end

  def handle_event("change-ages", %{"ages" => ages}, socket) do
    {:noreply, push_patch(socket, to: retain_path(socket, %{"ages" => ages}))}
  end

  def handle_event("start-over", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/landmarks")}
  end

  defp apply_params(socket, params) do
    civ = find_civ(socket, params["civ"])
    map = find_map(socket, params["map"])
    opponent = find_civ(socket, normalize_any(params["opponent"]))
    through = parse_through(params["ages"])
    step = resolve_step(params["step"], civ, map, params)

    socket
    |> assign(
      selected_civ: civ,
      selected_map: map,
      selected_opponent: opponent,
      selected_through: through,
      step: step,
      error: nil,
      open_menu: nil
    )
    |> maybe_load_paths()
    |> maybe_refresh_result()
  end

  defp maybe_load_paths(socket) do
    civ = socket.assigns.selected_civ
    key = {civ && civ.slug, selected_map_id(socket), socket.assigns.patch}

    cond do
      is_nil(civ) ->
        assign(socket, paths: [], paths_key: nil, recommendation: nil, loading: false)

      socket.assigns.paths_key == key ->
        socket

      true ->
        send(self(), {:fetch_paths, civ.slug})
        assign(socket, paths: [], paths_key: key, recommendation: nil, loading: true, open_menu: nil)
    end
  end

  defp resolve_step(step, civ, map, params) do
    requested =
      case step do
        "civ" -> :civ
        "map" -> :map
        "opponent" -> :opponent
        "result" -> :result
        _ -> infer_step(civ, map, params)
      end

    cond do
      requested in [:map, :opponent, :result] and is_nil(civ) -> :civ
      requested in [:opponent, :result] and is_nil(map) -> :map
      requested == :result and not Map.has_key?(params, "opponent") -> :opponent
      true -> requested
    end
  end

  defp infer_step(nil, _, _), do: :civ
  defp infer_step(_, nil, _), do: :map

  defp infer_step(_, _, params) do
    if Map.has_key?(params, "opponent"), do: :result, else: :opponent
  end

  defp find_civ(_socket, slug) when slug in [nil, ""], do: nil

  defp find_civ(socket, slug) do
    Enum.find(socket.assigns.civs, &(&1.slug == slug))
  end

  defp find_map(_socket, map) when map in [nil, ""], do: nil
  defp find_map(_socket, "any"), do: %{name: nil, any?: true, slug: nil, id: nil}

  defp find_map(socket, name) do
    Enum.find(socket.assigns.maps, &(&1.name == name or &1.slug == name))
  end

  defp normalize_any(value) when value in [nil, "", "any"], do: nil
  defp normalize_any(value), do: value

  defp retain_path(socket, overrides) do
    civ = overrides["civ"] || civ_slug(socket.assigns.selected_civ)
    map = overrides["map"] || map_param(socket.assigns.selected_map)

    opp =
      cond do
        Map.has_key?(overrides, "opponent") -> overrides["opponent"]
        socket.assigns.step == :result -> civ_slug(socket.assigns.selected_opponent) || "any"
        true -> civ_slug(socket.assigns.selected_opponent)
      end

    opp = if is_binary(opp) and opp == civ, do: "any", else: opp

    step =
      case socket.assigns.step do
        :result -> if map, do: "result", else: "map"
        :opponent -> if map, do: "opponent", else: "map"
        :map -> "map"
        _ -> "map"
      end

    ages =
      cond do
        Map.has_key?(overrides, "ages") -> ages_param(overrides["ages"])
        true -> ages_param(socket.assigns.selected_through)
      end

    attrs = %{"step" => step, "civ" => civ, "map" => map, "ages" => ages}

    attrs =
      cond do
        step == "result" -> Map.put(attrs, "opponent", opp || "any")
        true -> attrs
      end

    wizard_path(attrs)
  end

  defp result_path(socket, opponent) do
    wizard_path(%{
      "step" => "result",
      "civ" => civ_slug(socket.assigns.selected_civ),
      "map" => map_param(socket.assigns.selected_map),
      "opponent" => opponent,
      "ages" => ages_param(socket.assigns.selected_through)
    })
  end

  defp wizard_path(attrs) do
    query =
      attrs
      |> Map.new(fn {key, value} -> {to_string(key), value} end)
      |> Map.take(["step", "civ", "map", "opponent", "ages"])
      |> Enum.reject(fn {_key, value} -> value in [nil, ""] end)
      |> Map.new()

    if query == %{}, do: ~p"/landmarks", else: ~p"/landmarks?#{query}"
  end

  defp map_param(nil), do: nil
  defp map_param(%{any?: true}), do: "any"
  defp map_param(%{name: name}), do: name

  defp civ_slug(nil), do: nil
  defp civ_slug(%{slug: slug}), do: slug

  defp parse_through(value) when value in ["1-2", "2"], do: 2
  defp parse_through(value) when value in ["1-3", "3"], do: 3
  defp parse_through(_), do: 4

  defp ages_param(2), do: "1-2"
  defp ages_param(3), do: "1-3"
  defp ages_param("1-2"), do: "1-2"
  defp ages_param("1-3"), do: "1-3"
  defp ages_param(_), do: nil

  def through_choice(through) do
    Enum.find(@through_choices, &(&1.value == through)) || hd(@through_choices)
  end

  def path_landmarks(path) do
    [{path.age2, "Age II"}, {path.age3, "Age III"}, {path.age4, "Age IV"}]
    |> Enum.reject(fn {landmark, _} -> is_nil(landmark) or is_nil(landmark.name) end)
  end

  def through_range_label(2), do: "Age II"
  def through_range_label(3), do: "Age III"
  def through_range_label(_), do: "Age IV"

  defp maybe_refresh_result(socket) do
    if socket.assigns.step == :result do
      apply_recommendation(socket, opponent_slug(socket.assigns.selected_opponent))
    else
      socket
    end
  end

  defp apply_recommendation(socket, opponent) do
    civ = socket.assigns.selected_civ

    if is_nil(civ) do
      socket
    else
      through = socket.assigns.selected_through

      case AgeupsAPI.cached_recommendation(
             civ.slug,
             opponent,
             socket.assigns.patch,
             selected_map_id(socket),
             through
           ) do
        {:ok, rec} ->
          socket
          |> assign(recommendation: rec, loading_matchups: false)
          |> maybe_fill_any_map_matchup()

        :miss ->
          send(self(), {:load_recommendation, opponent, through})
          assign(socket, loading_matchups: true, open_menu: nil)
      end
    end
  end

  defp opponent_slug(nil), do: nil
  defp opponent_slug(%{slug: slug}), do: slug

  defp pills_locked?(socket) do
    socket.assigns.loading or socket.assigns.loading_matchups
  end

  defp maybe_fill_any_map_matchup(socket) do
    rec = socket.assigns.recommendation
    civ = socket.assigns.selected_civ
    opp = opponent_slug(socket.assigns.selected_opponent)
    map_id = selected_map_id(socket)

    cond do
      is_nil(rec) or is_nil(rec.path) or is_nil(opp) or is_nil(map_id) ->
        socket

      Map.get(rec, :any_map_matchup) ->
        socket

      true ->
        any_mu = AgeupsAPI.path_matchup_vs(civ.slug, rec.path, opp, socket.assigns.patch, map_id)
        assign(socket, recommendation: Map.put(rec, :any_map_matchup, any_mu))
    end
  end

  defp map_choices do
    maps =
      case MapPool.get() do
        {:ok, %{maps: maps}} ->
          Enum.map(maps, fn map ->
            %{name: map.name, any?: false, slug: map_slug(map.name), id: Map.get(map, :id)}
          end)

        _ ->
          []
      end

    [%{name: nil, any?: true, slug: nil, id: nil} | maps]
  end

  defp selected_map_id(socket) do
    case socket.assigns.selected_map do
      %{any?: true} -> nil
      %{id: id} when not is_nil(id) -> id
      _ -> nil
    end
  end

  def map_slug(nil), do: nil

  def map_slug(name) when is_binary(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "_")
    |> String.trim("_")
  end

  def map_icon(%{any?: true}), do: nil
  def map_icon(%{slug: slug}) when is_binary(slug), do: "/images/maps/#{slug}.png"
  def map_icon(%{name: name}) when is_binary(name), do: "/images/maps/#{map_slug(name)}.png"
  def map_icon(_), do: nil

  def result_stats(_civ, map, opponent, rec) do
    path = rec && rec.path
    mu = rec && rec.matchup
    any_mu = rec && Map.get(rec, :any_map_matchup)
    map_name = if map && !map.any?, do: map.name
    opp_label = opponent && opponent.label

    exact =
      cond do
        mu && opp_label && map_name ->
          %{
            wr: mu.win_rate,
            games: mu.games,
            title: "This exact combo",
            detail: "vs #{opp_label} on #{map_name}"
          }

        mu && opp_label ->
          %{
            wr: mu.win_rate,
            games: mu.games,
            title: "This exact combo",
            detail: "vs #{opp_label} · any map"
          }

        path && map_name ->
          %{
            wr: path.win_rate,
            games: path.games,
            title: "This exact combo",
            detail: "on #{map_name} · Any Civ"
          }

        path ->
          %{
            wr: path.win_rate,
            games: path.games,
            title: "This exact combo",
            detail: "any map · Any Civ"
          }

        true ->
          nil
      end

    any_map =
      if any_mu && opp_label && map_name do
        %{
          wr: any_mu.win_rate,
          games: any_mu.games,
          title: "This build vs #{opp_label}",
          detail: "any map"
        }
      end

    Enum.reject([exact, any_map], &is_nil/1)
  end

  defdelegate format_clock(seconds), to: AgeupsAPI
  defdelegate format_win_rate(rate), to: CivHelpers
  defdelegate format_number(number), to: CivHelpers
  defdelegate color_class(percentage, type), to: CivHelpers
end
