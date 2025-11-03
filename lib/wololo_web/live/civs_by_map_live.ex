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
    %{key: :golden_horde, label: "Golden Horde", image: "golden_horde"}
  ]

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    socket =
      assign(socket,
        maps: [],
        civs: @civs,
        league_options: @league_options,
        selected_league: nil,
        loading: true,
        error: nil
      )

    if connected?(socket) do
      send(self(), :fetch_initial_data)
    end

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("select-league", %{"league" => league}, socket) do
    socket =
      socket
      |> assign(loading: true, selected_league: league, error: nil)
      |> fetch_civs_data(league)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info(:fetch_initial_data, socket) do
    {:noreply, fetch_civs_data(socket)}
  end

  defp fetch_civs_data(socket, league \\ nil) do
    case CivsByMapAPI.fetch_civs_by_map(league) do
      {:ok, raw_data} ->
        transformed_data = CivsByMapAPI.transform_data(raw_data)
        assign(socket, maps: transformed_data, loading: false, error: nil)

      {:error, reason} ->
        assign(socket, maps: [], loading: false, error: "Failed to fetch Civs By Map: #{reason}")
    end
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
