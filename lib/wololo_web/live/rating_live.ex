defmodule WololoWeb.RatingLive do
  alias Wololo.PlayerGamesAPI
  use WololoWeb, :live_component
  import WololoWeb.Components.Spinner
  alias Wololo.PlayerStatsAPI
  import Wololo.Utils, only: [rating_to_color_map: 1]
  alias Phoenix.LiveView.AsyncResult

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:stats, %AsyncResult{})
     |> assign(:error, nil)}
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign(:stats, AsyncResult.loading())
      |> start_async(:get_stats, fn -> fetch_stats(assigns[:profile_id]) end)

    {:ok, socket}
  end

  def handle_async(:get_stats, {:ok, result}, socket) do
    case result do
      {:error, reason} ->
        socket =
          socket
          |> assign(:stats, AsyncResult.failed(%AsyncResult{}, reason))
          |> assign(:error, reason)

        {:noreply, socket}

      stats ->
        socket =
          socket
          |> assign(:stats, AsyncResult.ok(%AsyncResult{}, stats))
          |> push_event("update-player", %{
            movingAverages: stats.moving_averages,
            percentageTimeInRank: stats.percentage_time_in_rank
          })

        {:noreply, socket}
    end
  end

  @impl true
  def handle_async(:get_stats, {status, reason}, socket) when status in [:error, :exit, :ok] do
    socket =
      socket
      |> assign(:stats, AsyncResult.failed(%AsyncResult{}, reason))
      |> assign(:error, reason)

    {:noreply, socket}
  end

  def fetch_stats(profile_id) do
    WololoWeb.SentryContext.set_player_context(profile_id)

    with {:games, {:ok, opponents_data}} <-
           {:games, PlayerGamesAPI.get_players_games_statistics(profile_id)},
         {:stats, {:ok, player_stats}} <-
           {:stats, PlayerStatsAPI.fetch_player_data(profile_id, true)} do
      %{
        moving_averages: opponents_data[:ratings] || [],
        max_rating: player_stats[:max_rating],
        max_rating_7d: player_stats[:max_rating_7d],
        max_rating_1m: player_stats[:max_rating_1m],
        average_rating: player_stats[:average_rating],
        total_count: player_stats[:total_count],
        rating_spread: player_stats[:rating_spread],
        percentage_time_in_rank: player_stats[:percentage_time_in_rank]
      }
    else
      {:games, {:error, reason}} ->
        {:error, "Failed to fetch game statistics: #{reason}"}

      {:stats, {:error, reason}} ->
        {:error, "Failed to fetch player stats: #{reason}"}
    end
  end
end
