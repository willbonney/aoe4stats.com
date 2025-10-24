defmodule WololoWeb.AnalysisLive do
  use WololoWeb, :live_component
  import WololoWeb.Components.Spinner
  alias Wololo.PlayerStatsAPI
  alias Wololo.Utils
  alias Phoenix.LiveView.AsyncResult

  # Default score when there's not enough data to calculate a metric
  @default_score_insufficient_data 50.0

  defp sort_rating_history_by_time(rating_history) do
    rating_history
    |> Enum.sort_by(fn {timestamp, _} -> timestamp end)
  end

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:analysis, %AsyncResult{})
     |> assign(:error, nil)}
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign(:analysis, AsyncResult.loading())
      |> start_async(:get_analysis, fn -> fetch_analysis(assigns[:profile_id]) end)

    {:ok, socket}
  end

  @impl true
  def handle_async(:get_analysis, {:ok, result}, socket) do
    case result do
      {:error, reason} ->
        socket =
          socket
          |> assign(:analysis, AsyncResult.failed(%AsyncResult{}, reason))
          |> assign(:error, reason)

        {:noreply, socket}

      analysis ->
        socket =
          socket
          |> assign(:analysis, AsyncResult.ok(%AsyncResult{}, analysis))
          |> push_event("update-analysis", %{analysis: analysis})

        {:noreply, socket}
    end
  end

  @impl true
  def handle_async(:get_analysis, {status, reason}, socket) when status in [:error, :exit] do
    socket =
      socket
      |> assign(:analysis, AsyncResult.failed(%AsyncResult{}, reason))
      |> assign(:error, reason)

    {:noreply, socket}
  end

  # Calculate how stable a player's performance is
  # Lower score = more volatile, Higher score = more consistent
  # Uses standard deviation of rating changes between consecutive games
  defp calculate_consistency(rating_history) when is_map(rating_history) do
    sorted_ratings =
      rating_history
      |> sort_rating_history_by_time()
      |> Enum.map(fn {_, data} -> data["rating"] end)
      |> Enum.reject(&is_nil/1)

    if length(sorted_ratings) < 2 do
      0.0
    else
      # Calculate the differences between consecutive ratings
      rating_changes =
        sorted_ratings
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [rating1, rating2] -> abs(rating2 - rating1) end)

      # Calculate average rating change
      avg_change = Enum.sum(rating_changes) / length(rating_changes)

      # Calculate standard deviation
      variance =
        rating_changes
        |> Enum.map(fn change -> :math.pow(change - avg_change, 2) end)
        |> Enum.sum()
        |> Kernel./(length(rating_changes))

      std_dev = :math.sqrt(variance)

      # Normalize to 0-100 scale (higher is better)
      # Invert the score: lower std_dev = higher consistency score
      # Cap std_dev at 100, then invert
      inverted_score = 100.0 - min(std_dev, 100.0)
      max(inverted_score, 0.0)
    end
  end

  defp calculate_consistency(_), do: 0.0

  # Calculate how quickly a player recovers from losing streaks
  # Higher score = faster recovery
  defp calculate_recovery(rating_history) when is_map(rating_history) do
    # Sort rating history by timestamp
    sorted_entries = sort_rating_history_by_time(rating_history)

    if length(sorted_entries) < 5 do
      @default_score_insufficient_data
    else
      # Track all losing streaks and how quickly they were broken
      recovery_times =
        sorted_entries
        |> Enum.reduce({[], 0, false}, fn {_, data},
                                          {recoveries, current_streak, in_losing_streak} ->
          streak = data["streak"]

          cond do
            # Streak is negative (losing)
            streak < 0 ->
              {recoveries, abs(streak), true}

            # Streak is positive and we were in a losing streak (recovery!)
            streak > 0 and in_losing_streak ->
              {[current_streak | recoveries], 0, false}

            # No change
            true ->
              {recoveries, current_streak, in_losing_streak}
          end
        end)
        |> elem(0)

      if length(recovery_times) == 0 do
        # No losing streaks found - perfect recovery or not enough data
        100.0
      else
        # Average losing streak length before recovery
        avg_streak_before_recovery = Enum.sum(recovery_times) / length(recovery_times)

        # Normalize: shorter streaks = better recovery (0-100 scale)
        # Formula: 100 - (avg_streak * 10), capped between 0 and 100
        max(0.0, min(100.0, 100 - avg_streak_before_recovery * 10))
      end
    end
  end

  defp calculate_recovery(_), do: @default_score_insufficient_data

  # Calculate how well a player maintains winning streaks
  # Higher score = better at maintaining momentum
  defp calculate_momentum(rating_history) when is_map(rating_history) do
    sorted_entries =
      rating_history
      |> sort_rating_history_by_time()
      |> Enum.map(fn {_, data} -> data["streak"] end)
      |> Enum.reject(&is_nil/1)

    if length(sorted_entries) < 5 do
      @default_score_insufficient_data
    else
      # Find all positive streaks and calculate their average length
      positive_streaks =
        sorted_entries
        |> Enum.filter(fn streak -> streak > 0 end)

      if length(positive_streaks) == 0 do
        0.0
      else
        # Average winning streak length
        avg_win_streak = Enum.sum(positive_streaks) / length(positive_streaks)

        # Normalize to 0-100 scale
        # Formula: avg_streak * 20, capped at 100
        min(avg_win_streak * 20, 100.0)
      end
    end
  end

  defp calculate_momentum(_), do: @default_score_insufficient_data

  # Calculate if wins lead to more wins (positive) or losses lead to more losses (negative)
  # Higher score = better at avoiding tilt
  defp calculate_anti_tilt(rating_history) when is_map(rating_history) do
    sorted_entries = sort_rating_history_by_time(rating_history)

    if length(sorted_entries) < 10 do
      @default_score_insufficient_data
    else
      # Look at consecutive games: did wins lead to more wins?
      results =
        sorted_entries
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.reduce({0, 0, 0, 0}, fn [{_, data1}, {_, data2}],
                                        {win_win, win_loss, loss_win, loss_loss} ->
          streak1 = data1["streak"]
          streak2 = data2["streak"]

          # Determine if streak increased (win) or decreased (loss)
          game1_win = streak2 > streak1
          game2_win = data2["streak"] > 0

          case {game1_win, game2_win} do
            {true, true} -> {win_win + 1, win_loss, loss_win, loss_loss}
            {true, false} -> {win_win, win_loss + 1, loss_win, loss_loss}
            {false, true} -> {win_win, win_loss, loss_win + 1, loss_loss}
            {false, false} -> {win_win, win_loss, loss_win, loss_loss + 1}
          end
        end)

      {win_win, win_loss, loss_win, loss_loss} = results
      total = win_win + win_loss + loss_win + loss_loss

      if total == 0 do
        @default_score_insufficient_data
      else
        # Calculate the ratio of wins following wins vs losses following losses
        win_after_win_rate =
          if win_win + win_loss > 0, do: win_win / (win_win + win_loss), else: 0.5

        loss_after_loss_rate =
          if loss_win + loss_loss > 0, do: loss_loss / (loss_win + loss_loss), else: 0.5

        # Good anti-tilt = high win_after_win, low loss_after_loss
        anti_tilt_score = (win_after_win_rate + (1 - loss_after_loss_rate)) / 2

        # Convert to 0-100 scale
        anti_tilt_score * 100
      end
    end
  end

  defp calculate_anti_tilt(_), do: @default_score_insufficient_data

  # Calculate performance under pressure (near rank thresholds)
  # Higher score = better clutch player
  defp calculate_pressure_performance(rating_history) when is_map(rating_history) do
    # Get rank thresholds from Utils module
    thresholds = Utils.get_rank_thresholds()
    threshold_range = 25

    sorted_entries = sort_rating_history_by_time(rating_history)

    if length(sorted_entries) < 5 do
      @default_score_insufficient_data
    else
      # Find games near thresholds and check win rate
      {pressure_wins, pressure_total} =
        sorted_entries
        |> Enum.reduce({0, 0}, fn {_, data}, {wins, total} ->
          rating = data["rating"]
          streak = data["streak"]

          # Check if rating is near any threshold
          near_threshold =
            Enum.any?(thresholds, fn threshold ->
              abs(rating - threshold) <= threshold_range
            end)

          if near_threshold do
            # Consider it a win if streak is positive
            win = if streak > 0, do: 1, else: 0
            {wins + win, total + 1}
          else
            {wins, total}
          end
        end)

      if pressure_total == 0 do
        @default_score_insufficient_data
      else
        # Calculate win rate under pressure
        pressure_win_rate = pressure_wins / pressure_total

        # Convert to 0-100 scale
        pressure_win_rate * 100
      end
    end
  end

  defp calculate_pressure_performance(_), do: @default_score_insufficient_data

  # Calculate how efficiently a player gains rating over time
  # Higher score = more efficient climber
  defp calculate_rating_efficiency(rating_history) when is_map(rating_history) do
    sorted_entries = sort_rating_history_by_time(rating_history)

    if length(sorted_entries) < 10 do
      @default_score_insufficient_data
    else
      first_rating = sorted_entries |> List.first() |> elem(1) |> Map.get("rating")
      last_rating = sorted_entries |> List.last() |> elem(1) |> Map.get("rating")
      games_played = length(sorted_entries)

      rating_change = last_rating - first_rating
      rating_per_game = rating_change / games_played

      # Normalize to 0-100 scale
      # Positive rating per game is good, negative is bad
      # Formula: (rating_per_game + 5) * 10, capped between 0 and 100
      max(0.0, min(100.0, (rating_per_game + 5) * 10))
    end
  end

  defp calculate_rating_efficiency(_), do: @default_score_insufficient_data

  # Calculate how versatile a player is across different civilizations
  # Higher score = more versatile (plays multiple civs well)
  # Uses civ_stats from the API which includes civilization, games_count, win_rate
  defp calculate_versatility(civ_stats) when is_list(civ_stats) and length(civ_stats) > 0 do
    # Calculate total games across all civs
    total_games = Enum.sum(Enum.map(civ_stats, fn civ -> civ["games_count"] end))

    if total_games < 10 do
      @default_score_insufficient_data
    else
      # Define minimum games threshold (5% of total games, minimum 5)
      min_games_threshold = max(5, round(total_games * 0.05))

      # Filter to civs played enough (at least min_games_threshold)
      civs_played_enough_list =
        civ_stats
        |> Enum.filter(fn civ -> civ["games_count"] >= min_games_threshold end)

      civs_played_enough = length(civs_played_enough_list)

      # Count civs with good performance (>50% win rate)
      # win_rate from API is already a percentage (0-100), so divide by 100
      good_civs =
        civs_played_enough_list
        |> Enum.count(fn civ -> civ["win_rate"] >= 50.0 end)

      # Calculate versatility score as percentage of civs played well
      # out of the civs they've played enough
      # Formula: (good_civs / civs_played_enough) * 100
      # Example: 3 good civs out of 4 played enough = 75% versatility
      if civs_played_enough > 0 do
        good_civs / civs_played_enough * 100.0
      else
        @default_score_insufficient_data
      end
    end
  end

  defp calculate_versatility(_), do: @default_score_insufficient_data

  def fetch_analysis(profile_id) do
    case PlayerStatsAPI.fetch_player_data(profile_id, false) do
      {:ok, player_data} ->
        rating_history = get_in(player_data, ["modes", "rm_solo", "rating_history"])
        civ_stats = get_in(player_data, ["modes", "rm_solo", "civilizations"]) || []

        if is_nil(rating_history) or map_size(rating_history) == 0 do
          {:error, "No rating history available"}
        else
          %{
            consistency: calculate_consistency(rating_history),
            recovery: calculate_recovery(rating_history),
            momentum: calculate_momentum(rating_history),
            anti_tilt: calculate_anti_tilt(rating_history),
            pressure_performance: calculate_pressure_performance(rating_history),
            rating_efficiency: calculate_rating_efficiency(rating_history),
            versatility: calculate_versatility(civ_stats)
          }
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end
