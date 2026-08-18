defmodule WololoWeb.LandmarksLive do
  use WololoWeb, :live_view

  alias Wololo.AgeupsAPI
  alias Wololo.Civilizations
  alias Wololo.CivsByMapAPI
  alias Wololo.MapPool
  alias WololoWeb.CivHelpers
  import WololoWeb.Components.Spinner

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
        patch: AgeupsAPI.fallback_patch(),
        patch_label: nil,
        paths: [],
        recommendation: nil,
        map_wr: nil,
        loading: true,
        loading_matchups: false,
        error: nil,
        last_updated: nil
      )

    if connected?(socket), do: send(self(), :load_options)
    {:ok, socket}
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
     assign(socket,
       patch: patch,
       patch_label: label,
       last_updated: last_updated,
       loading: false,
       error: nil
     )}
  end

  def handle_info({:fetch_paths, civ_slug}, socket) do
    if socket.assigns.selected_civ && socket.assigns.selected_civ.slug == civ_slug do
      case AgeupsAPI.fetch_paths(civ_slug, socket.assigns.patch) do
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

  def handle_info({:load_recommendation, opponent}, socket) do
    civ = socket.assigns.selected_civ
    same_opp = opponent_slug(socket.assigns.selected_opponent) == opponent

    if civ && same_opp do
      case AgeupsAPI.recommend_for(civ.slug, opponent, socket.assigns.patch) do
        {:ok, rec} ->
          {:noreply, assign(socket, recommendation: rec, loading_matchups: false, error: nil)}

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

  def handle_info({:fetch_map_wr, civ_key, map_name}, socket) do
    same_civ = socket.assigns.selected_civ && socket.assigns.selected_civ.key == civ_key
    same_map = socket.assigns.selected_map && socket.assigns.selected_map.name == map_name

    if same_civ and same_map do
      wr = lookup_map_wr(civ_key, map_name)
      {:noreply, assign(socket, map_wr: wr)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("select-civ", %{"civ" => slug}, socket) do
    civ = Enum.find(socket.assigns.civs, &(&1.slug == slug))

    socket =
      if civ do
        send(self(), {:fetch_paths, civ.slug})

        socket
        |> assign(
          selected_civ: civ,
          step: :map,
          paths: [],
          recommendation: nil,
          loading: true,
          error: nil
        )
        |> maybe_refresh_map_wr()
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_event("select-map", params, socket) do
    name = params["map"]

    map =
      cond do
        name in [nil, ""] -> %{name: nil, any?: true, slug: nil}
        true -> Enum.find(socket.assigns.maps, &(&1.name == name))
      end

    socket =
      if map do
        socket
        |> assign(selected_map: map, map_wr: nil, step: :opponent)
        |> maybe_refresh_map_wr()
        |> maybe_refresh_result()
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_event("select-opponent", %{"civ" => slug}, socket) do
    civ = Enum.find(socket.assigns.civs, &(&1.slug == slug))

    socket =
      if civ do
        socket
        |> assign(selected_opponent: civ, step: :result)
        |> apply_recommendation(civ.slug)
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_event("skip-opponent", _params, socket) do
    {:noreply,
     socket
     |> assign(selected_opponent: nil, step: :result)
     |> apply_recommendation(nil)}
  end

  def handle_event("goto", %{"step" => step}, socket) do
    socket =
      case step do
        "civ" -> assign(socket, step: :civ)
        "map" -> if socket.assigns.selected_civ, do: assign(socket, step: :map), else: socket
        "opponent" -> if socket.assigns.selected_map, do: assign(socket, step: :opponent), else: socket
        "result" ->
          if socket.assigns.selected_map do
            socket
            |> assign(step: :result)
            |> maybe_refresh_result()
          else
            socket
          end
        _ -> socket
      end

    {:noreply, socket}
  end

  def handle_event("start-over", _params, socket) do
    {:noreply,
     assign(socket,
       step: :civ,
       selected_civ: nil,
       selected_map: nil,
       selected_opponent: nil,
       paths: [],
       recommendation: nil,
       map_wr: nil,
       loading: false,
       loading_matchups: false,
       error: nil
     )}
  end

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
      case AgeupsAPI.cached_recommendation(civ.slug, opponent, socket.assigns.patch) do
        {:ok, rec} ->
          assign(socket, recommendation: rec, loading_matchups: false)

        :miss ->
          send(self(), {:load_recommendation, opponent})
          assign(socket, loading_matchups: true)
      end
    end
  end

  defp opponent_slug(nil), do: nil
  defp opponent_slug(%{slug: slug}), do: slug

  defp maybe_refresh_map_wr(socket) do
    civ = socket.assigns.selected_civ
    map = socket.assigns.selected_map

    if civ && map && !map.any? do
      send(self(), {:fetch_map_wr, civ.key, map.name})
    end

    socket
  end

  defp lookup_map_wr(civ_key, map_name) do
    case CivsByMapAPI.fetch_civs_by_map(nil) do
      {:ok, raw} ->
        raw
        |> CivsByMapAPI.transform_data()
        |> Enum.find(&(MapPool.normalize_name(&1.name) == MapPool.normalize_name(map_name)))
        |> case do
          %{civs: civs} -> get_in(civs, [civ_key, :win_rate])
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp map_choices do
    maps =
      case MapPool.get() do
        {:ok, %{maps: maps}} ->
          Enum.map(maps, fn map ->
            %{name: map.name, any?: false, slug: map_slug(map.name)}
          end)

        _ ->
          []
      end

    [%{name: nil, any?: true, slug: nil} | maps]
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

  defdelegate format_clock(seconds), to: AgeupsAPI
  defdelegate format_win_rate(rate), to: CivHelpers
  defdelegate format_number(number), to: CivHelpers
  defdelegate color_class(percentage, type), to: CivHelpers
end
