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
        last_updated: nil,
        paths_key: nil
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

  def handle_info({:load_recommendation, opponent}, socket) do
    civ = socket.assigns.selected_civ
    same_opp = opponent_slug(socket.assigns.selected_opponent) == opponent

    if civ && same_opp do
      case AgeupsAPI.recommend_for(civ.slug, opponent, socket.assigns.patch, selected_map_id(socket)) do
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

  def handle_event("goto", %{"step" => step}, socket) do
    {:noreply, push_patch(socket, to: path_for_step(socket, step))}
  end

  def handle_event("start-over", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/landmarks")}
  end

  defp apply_params(socket, params) do
    civ = find_civ(socket, params["civ"])
    map = find_map(socket, params["map"])
    opponent = find_civ(socket, normalize_any(params["opponent"]))
    step = resolve_step(params["step"], civ, map, params)

    socket
    |> assign(
      selected_civ: civ,
      selected_map: map,
      selected_opponent: opponent,
      step: step,
      error: nil
    )
    |> maybe_load_paths()
    |> maybe_refresh_map_wr()
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
        assign(socket, paths: [], paths_key: key, recommendation: nil, loading: true)
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

  defp path_for_step(socket, "civ") do
    wizard_path(%{"step" => "civ", "civ" => civ_slug(socket.assigns.selected_civ)})
  end

  defp path_for_step(socket, "map") do
    wizard_path(%{
      "step" => "map",
      "civ" => civ_slug(socket.assigns.selected_civ),
      "map" => map_param(socket.assigns.selected_map)
    })
  end

  defp path_for_step(socket, "opponent") do
    wizard_path(%{
      "step" => "opponent",
      "civ" => civ_slug(socket.assigns.selected_civ),
      "map" => map_param(socket.assigns.selected_map)
    })
  end

  defp path_for_step(socket, "result") do
    result_path(socket, civ_slug(socket.assigns.selected_opponent) || "any")
  end

  defp path_for_step(_socket, _), do: ~p"/landmarks"

  defp result_path(socket, opponent) do
    wizard_path(%{
      "step" => "result",
      "civ" => civ_slug(socket.assigns.selected_civ),
      "map" => map_param(socket.assigns.selected_map),
      "opponent" => opponent
    })
  end

  defp wizard_path(attrs) do
    query =
      attrs
      |> Map.new(fn {key, value} -> {to_string(key), value} end)
      |> Map.take(["step", "civ", "map", "opponent"])
      |> Enum.reject(fn {_key, value} -> value in [nil, ""] end)
      |> Map.new()

    if query == %{}, do: ~p"/landmarks", else: ~p"/landmarks?#{query}"
  end

  defp map_param(nil), do: nil
  defp map_param(%{any?: true}), do: "any"
  defp map_param(%{name: name}), do: name

  defp civ_slug(nil), do: nil
  defp civ_slug(%{slug: slug}), do: slug

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
      case AgeupsAPI.cached_recommendation(civ.slug, opponent, socket.assigns.patch, selected_map_id(socket)) do
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

  defdelegate format_clock(seconds), to: AgeupsAPI
  defdelegate format_win_rate(rate), to: CivHelpers
  defdelegate format_number(number), to: CivHelpers
  defdelegate color_class(percentage, type), to: CivHelpers
end
