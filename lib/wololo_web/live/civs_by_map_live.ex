defmodule WololoWeb.CivsByMapLive do
  use WololoWeb, :live_view
  alias Wololo.CivsByMapAPI
  alias Wololo.Cldr
  require Logger
  import WololoWeb.Components.Spinner

  @league_options [
    {"Bronze", "bronze"},
    {"Silver", "silver"},
    {"Gold", "gold"},
    {"Platinum", "platinum"},
    {"Diamond", "diamond"},
    {"Conqueror", "conqueror"},
    {"≥ Platinum", "≥platinum"},
    {"≥ Diamond", "≥diamond"},
    {"≥ Conq 1", "≥conqueror_1"},
    {"≥ Conq 2", "≥conqueror_2"},
    {"≥ Conq 3", "≥conqueror_3"},
    {"≥ Conq 4", "≥conqueror_4"}
  ]


  @civs [
    %{key: :name, label: "Map", image: nil},
    %{key: :abbasid_dynasty, label: "Abbasid", image: "abbasid_dynasty"},
    %{key: :chinese, label: "Chinese", image: "chinese"},
    %{key: :delhi_sultanate, label: "Delhi", image: "delhi_sultanate"},
    %{key: :english, label: "English", image: "english"},
    %{key: :french, label: "French", image: "french"},
    %{key: :holy_roman_empire, label: "HRE", image: "holy_roman_empire"},
    %{key: :mongols, label: "Mongols", image: "mongols"},
    %{key: :rus, label: "Rus", image: "rus"},
    %{key: :ottomans, label: "Ottomans", image: "ottomans"},
    %{key: :malians, label: "Malians", image: "malians"},
    %{key: :byzantines, label: "Byzantines", image: "byzantines"},
    %{key: :japanese, label: "Japanese", image: "japanese"},
    %{key: :ayyubids, label: "Ayyubids", image: "ayyubids"},
    %{key: :jeanne_darc, label: "JDA", image: "jeanne_darc"},
    %{key: :order_of_the_dragon, label: "OOTD", image: "order_of_the_dragon"},
    %{key: :zhu_xis_legacy, label: "ZXL", image: "zhu_xis_legacy"},
    %{key: :knights_templar, label: "KTP", image: "knights_templar"},
    %{key: :house_of_lancaster, label: "HOL", image: "house_of_lancaster"},
    %{key: :tughlaq_dynasty, label: "Tughlaq", image: "tughlaq_dynasty"},
    %{key: :sengoku_daimyo, label: "Sengoku", image: "sengoku_daimyo"},
    %{key: :macedonian_dynasty, label: "Macedonian", image: "macedonian_dynasty"},
    %{key: :golden_horde, label: "GOH", image: "golden_horde"}
  ]

  def mount(_params, _session, socket) do
    # Initialize all civs as selected (except the first one which is "Map")
    selected_civs = @civs |> Enum.drop(1) |> Enum.map(& &1.key) |> MapSet.new()

    socket =
      assign(socket,
        maps: [],
        civs: @civs,
        league_options: @league_options,
        selected_league: nil,
        loading: true,
        error: nil,
        selected_civs: selected_civs,
        selected_maps: MapSet.new(),
        show_civ_filter: false,
        show_map_filter: false,
        data_fetched: false
      )

    if connected?(socket) do
      send(self(), :fetch_initial_data)
    end

    {:ok, socket}
  end

  def handle_event("select-league", %{"league" => league}, socket) do
    socket =
      socket
      |> assign(loading: true, selected_league: league, error: nil)
      |> fetch_civs_data(league)
      |> save_filters_to_client()

    {:noreply, socket}
  end

  def handle_event("toggle-civ", %{"civ" => civ_key}, socket) do
    civ_atom = String.to_existing_atom(civ_key)
    selected_civs = socket.assigns.selected_civs

    new_selected_civs =
      if MapSet.member?(selected_civs, civ_atom) do
        MapSet.delete(selected_civs, civ_atom)
      else
        MapSet.put(selected_civs, civ_atom)
      end

    socket =
      socket
      |> assign(selected_civs: new_selected_civs)
      |> save_filters_to_client()

    {:noreply, socket}
  end

  def handle_event("toggle-map", %{"map" => map_name}, socket) do
    selected_maps = socket.assigns.selected_maps

    new_selected_maps =
      if MapSet.member?(selected_maps, map_name) do
        MapSet.delete(selected_maps, map_name)
      else
        MapSet.put(selected_maps, map_name)
      end

    socket =
      socket
      |> assign(selected_maps: new_selected_maps)
      |> save_filters_to_client()

    {:noreply, socket}
  end

  def handle_event("toggle-civ-filter", _params, socket) do
    {:noreply, assign(socket, show_civ_filter: !socket.assigns.show_civ_filter)}
  end

  def handle_event("toggle-map-filter", _params, socket) do
    {:noreply, assign(socket, show_map_filter: !socket.assigns.show_map_filter)}
  end

  def handle_event("select-all-civs", _params, socket) do
    all_civs = @civs |> Enum.drop(1) |> Enum.map(& &1.key) |> MapSet.new()

    socket =
      socket
      |> assign(selected_civs: all_civs)
      |> save_filters_to_client()

    {:noreply, socket}
  end

  def handle_event("deselect-all-civs", _params, socket) do
    socket =
      socket
      |> assign(selected_civs: MapSet.new())
      |> save_filters_to_client()

    {:noreply, socket}
  end

  def handle_event("select-all-maps", _params, socket) do
    all_maps = socket.assigns.maps |> Enum.map(& &1.name) |> MapSet.new()

    socket =
      socket
      |> assign(selected_maps: all_maps)
      |> save_filters_to_client()

    {:noreply, socket}
  end

  def handle_event("deselect-all-maps", _params, socket) do
    socket =
      socket
      |> assign(selected_maps: MapSet.new())
      |> save_filters_to_client()

    {:noreply, socket}
  end

  def handle_event("reset-all-filters", _params, socket) do
    all_civs = @civs |> Enum.drop(1) |> Enum.map(& &1.key) |> MapSet.new()

    socket =
      socket
      |> assign(
        loading: true,
        selected_civs: all_civs,
        selected_league: nil,
        show_civ_filter: false,
        show_map_filter: false
      )
      |> fetch_civs_data(nil)
      |> save_filters_to_client()

    {:noreply, socket}
  end

  def handle_event("load-filters", params, socket) do
    selected_civs =
      params
      |> Map.get("selectedCivs", [])
      |> Enum.map(&String.to_existing_atom/1)
      |> MapSet.new()

    selected_maps = params |> Map.get("selectedMaps", []) |> MapSet.new()
    selected_league = Map.get(params, "selectedLeague")

    socket =
      socket
      |> maybe_assign_if_not_empty(:selected_civs, selected_civs)
      |> maybe_assign_if_not_empty(:selected_maps, selected_maps)
      |> maybe_assign_league(selected_league)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info(:fetch_initial_data, socket) do
    # Skip if data has already been fetched (e.g., from loaded filters with league)
    if socket.assigns.data_fetched do
      {:noreply, socket}
    else
      {:noreply, fetch_civs_data(socket)}
    end
  end

  defp fetch_civs_data(socket, league \\ nil) do
    case CivsByMapAPI.fetch_civs_by_map(league) do
      {:ok, raw_data} ->
        transformed_data = CivsByMapAPI.transform_data(raw_data)
        all_maps = transformed_data |> Enum.map(& &1.name) |> MapSet.new()

        # Preserve user's selected maps if they exist, filtering out any that are no longer available
        # Only reset to all maps if current selection is empty (initial load)
        current_selected = socket.assigns.selected_maps

        new_selected_maps =
          if MapSet.size(current_selected) > 0 do
            MapSet.intersection(current_selected, all_maps)
            |> then(fn intersection ->
              # If intersection is empty (all previously selected maps are gone), select all new maps
              if MapSet.size(intersection) == 0, do: all_maps, else: intersection
            end)
          else
            all_maps
          end

        assign(socket,
          maps: transformed_data,
          selected_maps: new_selected_maps,
          loading: false,
          error: nil,
          data_fetched: true
        )

      {:error, reason} ->
        assign(socket,
          maps: [],
          loading: false,
          error: "Failed to fetch Civs By Map: #{reason}",
          data_fetched: true
        )
    end
  end

  def filtered_maps(maps, selected_maps) do
    if MapSet.size(selected_maps) == 0 do
      maps
    else
      Enum.filter(maps, fn map -> MapSet.member?(selected_maps, map.name) end)
    end
  end

  def filtered_civs(civs, selected_civs) do
    # Always include the first element (Map column)
    [Enum.at(civs, 0)] ++
      Enum.filter(Enum.drop(civs, 1), fn civ -> MapSet.member?(selected_civs, civ.key) end)
  end

  def civ_header(assigns) do
    ~H"""
    <div class="flex items-center flex-col text-center">
      <%= if @image do %>
        <img src={"/images/#{@image}.png"} alt={@label} class="w-10 h-6 mb-1" />
      <% end %>
       <span class="dark:text-stone-400">{@label}</span>
    </div>
    """
  end

  defp format_number(nil), do: "N/A"

  defp format_number(number) when is_integer(number) do
    case Cldr.Number.to_string(number) do
      {:ok, formatted} -> formatted
      {:error, _} -> Integer.to_string(number)
    end
  end

  defp format_number(number), do: number

  defp save_filters_to_client(socket) do
    filters = %{
      selectedCivs:
        socket.assigns.selected_civs |> MapSet.to_list() |> Enum.map(&Atom.to_string/1),
      selectedMaps: socket.assigns.selected_maps |> MapSet.to_list(),
      selectedLeague: socket.assigns.selected_league
    }

    Phoenix.LiveView.push_event(socket, "save-filters", filters)
  end

  defp maybe_assign_if_not_empty(socket, key, value) do
    if MapSet.size(value) > 0 do
      assign(socket, key, value)
    else
      socket
    end
  end
  defp maybe_assign_league(socket, nil), do: socket

  defp maybe_assign_league(socket, league) when is_binary(league) and byte_size(league) > 0 do
    socket
    |> assign(selected_league: league)
    |> fetch_civs_data(league)
  end

  defp maybe_assign_league(socket, _), do: socket



  def color_class(percentage, type) when is_binary(percentage) do
    case Float.parse(percentage) do
      {value, "%"} -> color_class(value, type)
      # Default color for invalid input
      _ -> "bg-gray-100"
    end
  end

  def color_class(percentage, type) when is_number(percentage) and type in [:bg, :text] do
    prefix = if type == :bg, do: "bg", else: "text"

    cond do
      percentage < 39 -> "#{prefix}-red-700"
      percentage < 42 -> "#{prefix}-red-600"
      percentage < 45 -> "#{prefix}-red-500"
      percentage < 47 -> "#{prefix}-red-400"
      percentage < 49 -> "#{prefix}-red-300"
      percentage < 50 -> "#{prefix}-red-200"
      percentage == 50 -> "#{prefix}-gray-200"
      percentage < 51 -> "#{prefix}-green-200"
      percentage < 53 -> "#{prefix}-green-300"
      percentage < 55 -> "#{prefix}-green-400"
      percentage < 60 -> "#{prefix}-green-500"
      percentage < 65 -> "#{prefix}-green-600"
      percentage < 70 -> "#{prefix}-green-700"
      percentage < 63 -> "#{prefix}-green-800"
      percentage < 65 -> "#{prefix}-green-900"
      percentage < 67 -> "#{prefix}-green-950"
      true -> "#FFF"
    end
  end

  def color_class(_, type) when type in [:bg, :text] do
    if type == :bg, do: "bg-gray-100", else: "text-gray-600"
  end
end
