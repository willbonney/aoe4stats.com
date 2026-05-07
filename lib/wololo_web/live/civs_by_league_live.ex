defmodule WololoWeb.CivsByLeagueLive do
  use WololoWeb, :live_view
  alias Wololo.CivsByLeagueAPI
  require Logger
  import WololoWeb.Components.Spinner



  # Civilization definitions with flag-inspired colors
  @civs [
    %{key: "abbasid_dynasty", label: "Abbasid", image: "abbasid_dynasty", color: "#37474F"},
    %{key: "chinese", label: "Chinese", image: "chinese", color: "#E53935"},
    %{key: "delhi_sultanate", label: "Delhi", image: "delhi_sultanate", color: "#2E7D32"},
    %{key: "english", label: "English", image: "english", color: "#EF5350"},
    %{key: "french", label: "French", image: "french", color: "#1565C0"},
    %{key: "holy_roman_empire", label: "HRE", image: "holy_roman_empire", color: "#F9A825"},
    %{key: "mongols", label: "Mongols", image: "mongols", color: "#0288D1"},
    %{key: "rus", label: "Rus", image: "rus", color: "#C62828"},
    %{key: "ottomans", label: "Ottomans", image: "ottomans", color: "#558B2F"},
    %{key: "malians", label: "Malians", image: "malians", color: "#FF8F00"},
    %{key: "byzantines", label: "Byzantines", image: "byzantines", color: "#7B1FA2"},
    %{key: "japanese", label: "Japanese", image: "japanese", color: "#FFB300"},
    %{key: "ayyubids", label: "Ayyubids", image: "ayyubids", color: "#E65100"},
    %{key: "jeanne_darc", label: "JDA", image: "jeanne_darc", color: "#C0CA33"},
    %{key: "order_of_the_dragon", label: "OOTD", image: "order_of_the_dragon", color: "#9E9D24"},
    %{key: "zhu_xis_legacy", label: "ZXL", image: "zhu_xis_legacy", color: "#00897B"},
    %{key: "knights_templar", label: "KTP", image: "knights_templar", color: "#D32F2F"},
    %{key: "house_of_lancaster", label: "HOL", image: "house_of_lancaster", color: "#00695C"},
    %{key: "tughlaq_dynasty", label: "Tughlaq", image: "tughlaq_dynasty", color: "#78909C"},
    %{key: "sengoku_daimyo", label: "Sengoku", image: "sengoku_daimyo", color: "#D84315"},
    %{key: "macedonian_dynasty", label: "Macedonian", image: "macedonian_dynasty", color: "#AD1457"},
    %{key: "golden_horde", label: "GOH", image: "golden_horde", color: "#FF1744"},
    %{key: "jin_dynasty", label: "JIN", image: "jin_dynasty", color: "#E8E43B"}
  ]

  def mount(_params, _session, socket) do
    selected_civs = MapSet.new()

    socket =
      assign(socket,
        civs: @civs,
        selected_civs: selected_civs,
        show_civ_filter: true,
        loading: true,
        error: nil,
        all_league_data: nil
      )

    if connected?(socket) do
      send(self(), :fetch_data)
    end

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_info(:fetch_data, socket) do
    case CivsByLeagueAPI.fetch_all_leagues() do
      {:ok, data} ->
        socket =
          socket
          |> assign(loading: false, all_league_data: data, error: nil)
          |> push_chart_data()

        {:noreply, socket}

      {:error, reason} ->
        {:noreply, assign(socket, loading: false, error: "Failed to fetch data: #{reason}")}
    end
  end



  def handle_event("toggle-civ-filter", _params, socket) do
    {:noreply, assign(socket, show_civ_filter: !socket.assigns.show_civ_filter)}
  end

  def handle_event("toggle-civ", %{"civ" => civ_key}, socket) do
    selected = socket.assigns.selected_civs

    new_selected =
      if MapSet.member?(selected, civ_key) do
        MapSet.delete(selected, civ_key)
      else
        MapSet.put(selected, civ_key)
      end

    socket =
      socket
      |> assign(selected_civs: new_selected)
      |> push_chart_data()

    {:noreply, socket}
  end

  def handle_event("select-all-civs", _params, socket) do
    all_civs = @civs |> Enum.map(& &1.key) |> MapSet.new()

    socket =
      socket
      |> assign(selected_civs: all_civs)
      |> push_chart_data()

    {:noreply, socket}
  end

  def handle_event("deselect-all-civs", _params, socket) do
    socket =
      socket
      |> assign(selected_civs: MapSet.new())
      |> push_chart_data()

    {:noreply, socket}
  end

  def handle_event("reset-all-filters", _params, socket) do
    all_civs = @civs |> Enum.map(& &1.key) |> MapSet.new()

    socket =
      socket
      |> assign(
        loading: true,
        selected_civs: all_civs,
        show_civ_filter: false
      )

    send(self(), :fetch_data)
    {:noreply, socket}
  end

  defp push_chart_data(socket) do
    data = socket.assigns.all_league_data
    selected_civs = socket.assigns.selected_civs

    if data do
      league_labels = CivsByLeagueAPI.league_labels()
      league_order = CivsByLeagueAPI.league_order()

      # Determine which leagues to include based on fetched data
      active_leagues = Enum.filter(league_order, fn l -> Map.has_key?(data, l) end)
      labels = Enum.map(active_leagues, fn l -> Map.get(league_labels, l, l) end)

      datasets =
        @civs
        |> Enum.filter(fn civ -> MapSet.member?(selected_civs, civ.key) end)
        |> Enum.map(fn civ ->
          data_points =
            Enum.map(active_leagues, fn league ->
              get_in(data, [league, civ.key])
            end)

          %{
            label: civ.label,
            data: data_points,
            borderColor: civ.color,
            backgroundColor: civ.color <> "33",
            tension: 0,
            pointRadius: 5,
            pointHoverRadius: 8,
            borderWidth: 2.5,
            fill: false
          }
        end)

      push_event(socket, "update-civs-by-league", %{labels: labels, datasets: datasets})
    else
      socket
    end
  end
end
