defmodule WololoWeb.CivsMetaLive do
  use WololoWeb, :live_view
  alias Wololo.CivsMetaAPI
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

  def mount(_params, _session, socket) do
    socket =
      assign(socket,
        points: [],
        league_options: @league_options,
        selected_league: nil,
        loading: true,
        error: nil
      )

    if connected?(socket), do: send(self(), :fetch)
    {:ok, socket}
  end

  def handle_info(:fetch, socket) do
    {:noreply, fetch_data(socket, socket.assigns.selected_league)}
  end

  def handle_event("select-league", %{"league" => league}, socket) do
    league = if league in [nil, ""], do: nil, else: league

    {:noreply,
     socket
     |> assign(loading: true, selected_league: league, error: nil)
     |> fetch_data(league)}
  end

  defp fetch_data(socket, league) do
    case CivsMetaAPI.fetch_meta(league) do
      {:ok, raw} ->
        assign(socket, points: CivsMetaAPI.transform_data(raw), loading: false, error: nil)

      {:error, reason} ->
        assign(socket, points: [], loading: false, error: "Failed to fetch civ meta: #{reason}")
    end
  end
end
