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
    %{key: :golden_horde, label: "GOH", image: "golden_horde"},
    %{key: :jin_dynasty, label: "JIN", image: "jin_dynasty"}
  ]

  # Known civ atoms (excluding the "Map" column header)
  @civ_keys @civs |> Enum.drop(1) |> Enum.map(& &1.key)

  def mount(_params, _session, socket) do
    # Initialize all civs as selected (except the first one which is "Map")
    selected_civs = MapSet.new(@civ_keys)

    socket =
      assign(socket,
        maps: [],
        civs: @civs,
        league_options: @league_options,
        selected_league: nil,
        loading: true,
        error: nil,
        selected_civs: selected_civs,
        # nil means "not yet chosen" — fetch will default to all maps.
        # An empty MapSet means the user explicitly cleared all maps.
        selected_maps: nil,
        show_civ_filter: false,
        show_map_filter: false,
        data_fetched: false,
        # League the current `maps` payload was fetched for (may differ during restore)
        loaded_league: nil,
        filters_loaded: false,
        sort_by: nil,
        sort_dir: :desc
      )

    if connected?(socket) do
      # Fallback if the client hook never sends load-filters (no JS / blocked)
      Process.send_after(self(), :filters_load_timeout, 1_000)
    end

    {:ok, socket}
  end

  def handle_event("select-league", %{"league" => league}, socket) do
    league = normalize_league(league)

    socket =
      socket
      |> assign(loading: true, selected_league: league, error: nil)
      |> fetch_civs_data(league)
      |> save_filters_to_client()

    {:noreply, socket}
  end

  def handle_event("toggle-civ", %{"civ" => civ_key}, socket) do
    civ_atom = parse_civ_key(civ_key)

    socket =
      if civ_atom do
        selected_civs = socket.assigns.selected_civs

        new_selected_civs =
          if MapSet.member?(selected_civs, civ_atom) do
            MapSet.delete(selected_civs, civ_atom)
          else
            MapSet.put(selected_civs, civ_atom)
          end

        socket
        |> assign(selected_civs: new_selected_civs)
        |> save_filters_to_client()
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_event("toggle-map", %{"map" => map_name}, socket) do
    selected_maps = selected_maps_or_empty(socket)

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
    socket =
      socket
      |> assign(selected_civs: MapSet.new(@civ_keys))
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
    socket =
      socket
      |> assign(
        loading: true,
        selected_civs: MapSet.new(@civ_keys),
        # nil → fetch_civs_data will select all current maps
        selected_maps: nil,
        selected_league: nil,
        show_civ_filter: false,
        show_map_filter: false,
        sort_by: nil,
        sort_dir: :desc
      )
      |> fetch_civs_data(nil)
      |> save_filters_to_client()

    {:noreply, socket}
  end

  def handle_event("sort-column", %{"column" => column}, socket) do
    sort_key = parse_sort_column(column)

    socket =
      cond do
        is_nil(sort_key) ->
          socket

        socket.assigns.sort_by == sort_key ->
          assign(socket, sort_dir: toggle_sort_dir(socket.assigns.sort_dir))

        true ->
          assign(socket, sort_by: sort_key, sort_dir: :desc)
      end

    {:noreply, socket}
  end

  def handle_event("load-filters", params, socket) when is_map(params) do
    socket =
      socket
      |> apply_loaded_filters(params)
      |> assign(filters_loaded: true)

    # Always fetch with the (possibly restored) league so reconnects remount cleanly.
    # Cachex makes repeated fetches cheap.
    league = socket.assigns.selected_league

    socket =
      if socket.assigns.data_fetched and socket.assigns.loaded_league == league and
           maps_already_loaded?(socket) do
        # Surviving process reconnect with same league data: just re-apply map selection.
        reconcile_selected_maps(socket)
      else
        socket
        |> assign(loading: true, error: nil)
        |> fetch_civs_data(league)
      end

    # Re-persist reconciled filters (drops unknown civs / rotated-out maps)
    socket =
      if map_size(params) > 0 do
        save_filters_to_client(socket)
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_event("load-filters", _params, socket) do
    # Malformed payload — treat as empty prefs and continue loading
    socket =
      socket
      |> assign(filters_loaded: true, loading: true)
      |> fetch_civs_data(socket.assigns.selected_league)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info(:filters_load_timeout, socket) do
    if socket.assigns.filters_loaded do
      {:noreply, socket}
    else
      Logger.info("civs_by_map: filters load timeout, fetching defaults")

      socket =
        socket
        |> assign(filters_loaded: true, loading: true)
        |> fetch_civs_data(socket.assigns.selected_league)

      {:noreply, socket}
    end
  end

  defp apply_loaded_filters(socket, params) do
    socket =
      if Map.has_key?(params, "selectedCivs") do
        assign(socket, selected_civs: parse_selected_civs(params["selectedCivs"]))
      else
        socket
      end

    socket =
      if Map.has_key?(params, "selectedMaps") do
        assign(socket, selected_maps: parse_selected_maps(params["selectedMaps"]))
      else
        socket
      end

    if Map.has_key?(params, "selectedLeague") do
      assign(socket, selected_league: normalize_league(params["selectedLeague"]))
    else
      socket
    end
  end

  defp parse_selected_civs(keys) when is_list(keys) do
    keys
    |> Enum.filter(&is_binary/1)
    |> Enum.flat_map(fn key ->
      case parse_civ_key(key) do
        nil -> []
        atom -> [atom]
      end
    end)
    |> MapSet.new()
  end

  defp parse_selected_civs(_), do: MapSet.new(@civ_keys)

  defp parse_selected_maps(maps) when is_list(maps) do
    maps
    |> Enum.filter(&is_binary/1)
    |> MapSet.new()
  end

  defp parse_selected_maps(_), do: nil

  defp parse_civ_key(key) when is_binary(key) do
    Enum.find_value(@civ_keys, fn atom ->
      if Atom.to_string(atom) == key, do: atom
    end)
  end

  defp parse_civ_key(_), do: nil

  defp normalize_league(nil), do: nil
  defp normalize_league(""), do: nil
  defp normalize_league(league) when is_binary(league), do: league
  defp normalize_league(_), do: nil

  defp selected_maps_or_empty(socket) do
    case socket.assigns.selected_maps do
      %MapSet{} = maps -> maps
      _ -> MapSet.new()
    end
  end

  defp maps_already_loaded?(socket) do
    is_list(socket.assigns.maps) and socket.assigns.maps != []
  end

  defp reconcile_selected_maps(socket) do
    case socket.assigns.selected_maps do
      nil ->
        all_maps = socket.assigns.maps |> Enum.map(& &1.name) |> MapSet.new()
        assign(socket, selected_maps: all_maps)

      %MapSet{} = selected ->
        all_maps = socket.assigns.maps |> Enum.map(& &1.name) |> MapSet.new()
        assign(socket, selected_maps: reconcile_map_selection(selected, all_maps))

      _ ->
        socket
    end
  end

  defp fetch_civs_data(socket, league) do
    case CivsByMapAPI.fetch_civs_by_map(league) do
      {:ok, raw_data} ->
        transformed_data = CivsByMapAPI.transform_data(raw_data)
        all_maps = transformed_data |> Enum.map(& &1.name) |> MapSet.new()

        new_selected_maps =
          case socket.assigns.selected_maps do
            # First load / reset: select every map from the API
            nil ->
              all_maps

            %MapSet{} = current_selected ->
              reconcile_map_selection(current_selected, all_maps)

            _ ->
              all_maps
          end

        assign(socket,
          maps: transformed_data,
          selected_maps: new_selected_maps,
          loading: false,
          error: nil,
          data_fetched: true,
          loaded_league: league
        )

      {:error, reason} ->
        assign(socket,
          maps: [],
          selected_maps: selected_maps_or_empty(socket),
          loading: false,
          error: "Failed to fetch Civs By Map: #{reason}",
          data_fetched: true,
          loaded_league: league
        )
    end
  end

  # Preserve the user's selection across season map pool changes.
  # Empty selection is intentional (user cleared all). Only fall back to all
  # maps when every previously selected map has disappeared from the pool.
  defp reconcile_map_selection(current_selected, all_maps) do
    if MapSet.size(current_selected) == 0 do
      current_selected
    else
      intersection = MapSet.intersection(current_selected, all_maps)

      if MapSet.size(intersection) == 0 do
        all_maps
      else
        intersection
      end
    end
  end

  def filtered_maps(maps, selected_maps) do
    cond do
      is_nil(selected_maps) ->
        maps

      MapSet.size(selected_maps) == 0 ->
        maps

      true ->
        Enum.filter(maps, fn map -> MapSet.member?(selected_maps, map.name) end)
    end
  end

  def sorted_maps(maps, nil, _dir, _selected_civs), do: maps

  def sorted_maps(maps, :average, dir, selected_civs) do
    civ_keys = average_civ_keys(selected_civs)

    Enum.sort_by(maps, fn map ->
      val = map_average_win_rate(map, civ_keys)
      {is_nil(val), sort_numeric(val, dir)}
    end)
  end

  def sorted_maps(maps, civ_key, dir, _selected_civs) do
    Enum.sort_by(maps, fn map ->
      val = parse_win_rate(get_in(map, [:civs, civ_key, :win_rate]))
      {is_nil(val), sort_numeric(val, dir)}
    end)
  end

  def map_average_win_rate(map, civ_keys) do
    win_rates =
      civ_keys
      |> Enum.map(&parse_win_rate(get_in(map, [:civs, &1, :win_rate])))
      |> Enum.reject(&is_nil/1)

    if win_rates == [] do
      nil
    else
      Float.round(Enum.sum(win_rates) / length(win_rates), 2)
    end
  end

  def parse_win_rate(nil), do: nil
  def parse_win_rate("N/A"), do: nil
  def parse_win_rate(rate) when is_number(rate), do: rate / 1

  def parse_win_rate(rate) when is_binary(rate) do
    case Float.parse(rate) do
      {value, _} -> value
      :error -> nil
    end
  end

  def parse_win_rate(_), do: nil

  defp sort_numeric(nil, _), do: 0
  defp sort_numeric(val, :asc), do: val
  defp sort_numeric(val, :desc), do: -val

  defp average_civ_keys(%MapSet{} = selected_civs), do: MapSet.to_list(selected_civs)
  defp average_civ_keys(civ_keys) when is_list(civ_keys), do: civ_keys
  defp average_civ_keys(_), do: []

  defp parse_sort_column("average"), do: :average
  defp parse_sort_column(key), do: parse_civ_key(key)

  defp toggle_sort_dir(:desc), do: :asc
  defp toggle_sort_dir(:asc), do: :desc

  def filtered_civs(civs, selected_civs) do
    # Always include the first element (Map column)
    [Enum.at(civs, 0)] ++
      Enum.filter(Enum.drop(civs, 1), fn civ -> MapSet.member?(selected_civs, civ.key) end)
  end

  def civ_header(assigns) do
    assigns =
      assigns
      |> Map.put_new(:sortable, false)
      |> Map.put_new(:column, nil)
      |> Map.put_new(:sort_by, nil)
      |> Map.put_new(:sort_dir, :desc)
      |> then(fn assigns ->
        Map.put(
          assigns,
          :sorted,
          assigns[:sortable] && not is_nil(assigns[:column]) && assigns[:sort_by] == assigns[:column]
        )
      end)

    ~H"""
    <div
      class={[
        "flex items-center flex-col text-center",
        @sortable && "cursor-pointer select-none hover:opacity-80"
      ]}
      phx-click={@sortable && "sort-column"}
      phx-value-column={@column}
      title={@sortable && "Sort by #{@label} win rate"}
    >
      <%= if @image do %>
        <img src={"/images/#{@image}.png"} alt={@label} class="w-10 h-6 mb-1" />
      <% end %>
      <span class={[
        "inline-flex items-center justify-center gap-0.5 dark:text-stone-400",
        @sorted && "font-semibold text-stone-800 dark:text-zinc-100"
      ]}>
        {@label}
        <%= if @sorted do %>
          <.icon
            name={if @sort_dir == :asc, do: "hero-chevron-up-mini", else: "hero-chevron-down-mini"}
            class="h-3.5 w-3.5"
          />
        <% end %>
      </span>
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
      selectedMaps: selected_maps_list(socket.assigns.selected_maps),
      selectedLeague: socket.assigns.selected_league
    }

    Phoenix.LiveView.push_event(socket, "save-filters", filters)
  end

  defp selected_maps_list(nil), do: []
  defp selected_maps_list(%MapSet{} = maps), do: MapSet.to_list(maps)
  defp selected_maps_list(_), do: []

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
