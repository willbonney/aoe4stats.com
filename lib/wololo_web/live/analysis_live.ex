defmodule WololoWeb.AnalysisLive do
  use WololoWeb, :live_component
  import WololoWeb.Components.Spinner
  import WololoWeb.ErrorHelpers
  alias Wololo.PlayerStatsAPI
  alias Wololo.PlayerGamesAPI
  alias Wololo.Utils
  alias Phoenix.LiveView.AsyncResult
  require Logger

  # Default score when there's not enough data to calculate a metric
  @default_score_insufficient_data nil

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
        Logger.error("Analysis failed with reason: #{inspect(reason)}")

        socket =
          socket
          |> assign(:analysis, AsyncResult.failed(%AsyncResult{}, reason))
          |> assign(:error, reason)

        {:noreply, socket}

      analysis ->
        Logger.info("Analysis succeeded, pushing to client")

        # Filter out metrics with insufficient data (nil) for the chart
        chart_data =
          analysis
          |> Enum.reject(fn {_key, value} -> is_nil(value) end)
          |> Map.new()

        socket =
          socket
          |> assign(:analysis, AsyncResult.ok(%AsyncResult{}, analysis))
          |> push_event("update-analysis", %{analysis: chart_data})

        {:noreply, socket}
    end
  end

  @impl true
  def handle_async(:get_analysis, {status, reason}, socket) when status in [:error, :exit] do
    Logger.error("Analysis async failed with status: #{status}, reason: #{inspect(reason)}")

    socket =
      socket
      |> assign(:analysis, AsyncResult.failed(%AsyncResult{}, reason))
      |> assign(:error, reason)

    {:noreply, socket}
  end

  # Calculate how consistently a player performs near their peak rating
  # Higher score = consistently play near peak, Lower score = peak was a fluke or long ago
  defp calculate_peak_proximity(rating_history) when is_map(rating_history) do
    sorted_ratings =
      rating_history
      |> sort_rating_history_by_time()
      |> Enum.map(fn {_, data} -> data["rating"] end)
      |> Enum.reject(&is_nil/1)

    if length(sorted_ratings) < 10 do
      @default_score_insufficient_data
    else
      peak_rating = Enum.max(sorted_ratings)

      # Calculate average distance from peak in rating points
      avg_distance_from_peak =
        sorted_ratings
        |> Enum.map(fn rating -> peak_rating - rating end)
        |> Enum.sum()
        |> Kernel./(length(sorted_ratings))

      # Direct penalty: every 3 rating points away = -1 score point
      # Examples:
      #   0 points away (always at peak) = 100 score
      #   30 points away on average = 90 score
      #   60 points away = 80 score
      #   150 points away = 50 score
      #   300+ points away = 0 score
      score = 100.0 - avg_distance_from_peak / 3.0
      max(0.0, min(100.0, score))
    end
  end

  defp calculate_peak_proximity(_), do: @default_score_insufficient_data

  # Calculate how quickly a player recovers from losing streaks
  # Higher score = faster recovery
  defp calculate_recovery(rating_history) when is_map(rating_history) do
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
            streak < 0 ->
              {recoveries, abs(streak), true}

            # Recovery!
            streak > 0 and in_losing_streak ->
              {[current_streak | recoveries], 0, false}

            true ->
              {recoveries, current_streak, in_losing_streak}
          end
        end)
        |> elem(0)

      if length(recovery_times) == 0 do
        # No losing streaks found
        100.0
      else
        avg_streak_before_recovery = Enum.sum(recovery_times) / length(recovery_times)
        # Shorter streaks = better recovery
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
      positive_streaks =
        sorted_entries
        |> Enum.filter(fn streak -> streak > 0 end)

      if length(positive_streaks) == 0 do
        0.0
      else
        avg_win_streak = Enum.sum(positive_streaks) / length(positive_streaks)
        # Asymptotic curve: 4-game→95, 5-game→97, 6-game→98
        max(0.0, 100.0 * (1.0 - 1.05 / :math.pow(avg_win_streak, 2.3)))
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
          game1_win = data1["streak"] > 0
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
        win_after_win_rate =
          if win_win + win_loss > 0, do: win_win / (win_win + win_loss), else: 0.5

        loss_after_loss_rate =
          if loss_win + loss_loss > 0, do: loss_loss / (loss_win + loss_loss), else: 0.5

        # Good anti-tilt = high win_after_win, low loss_after_loss
        anti_tilt_score = (win_after_win_rate + (1 - loss_after_loss_rate)) / 2
        anti_tilt_score * 100
      end
    end
  end

  defp calculate_anti_tilt(_), do: @default_score_insufficient_data

  # Calculate performance under pressure (near rank thresholds)
  # Higher score = better clutch player
  defp calculate_pressure_performance(rating_history) when is_map(rating_history) do
    thresholds = Utils.get_rank_thresholds()
    # estimated by CascadeFury in the aoe4world discord
    threshold_range = 22

    sorted_entries = sort_rating_history_by_time(rating_history)

    if length(sorted_entries) < 5 do
      @default_score_insufficient_data
    else
      {pressure_wins, pressure_total} =
        sorted_entries
        |> Enum.reduce({0, 0}, fn {_, data}, {wins, total} ->
          rating = data["rating"]
          streak = data["streak"]

          near_threshold =
            Enum.any?(thresholds, fn threshold ->
              abs(rating - threshold) <= threshold_range
            end)

          if near_threshold do
            win = if streak > 0, do: 1, else: 0
            {wins + win, total + 1}
          else
            {wins, total}
          end
        end)

      if pressure_total == 0 do
        @default_score_insufficient_data
      else
        pressure_win_rate = pressure_wins / pressure_total
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

      max(0.0, min(100.0, (rating_per_game + 5) * 10))
    end
  end

  defp calculate_rating_efficiency(_), do: @default_score_insufficient_data

  # Calculate how versatile a player is across different civilizations
  # Higher score = more versatile (plays multiple civs well)
  defp calculate_versatility(civ_stats) when is_list(civ_stats) and length(civ_stats) > 0 do
    total_games = Enum.sum(Enum.map(civ_stats, fn civ -> civ["games_count"] end))

    if total_games < 10 do
      @default_score_insufficient_data
    else
      # Define minimum games threshold (5% of total games, minimum 5)
      min_games_threshold = max(5, round(total_games * 0.05))

      civs_played_enough_list =
        civ_stats
        |> Enum.filter(fn civ -> civ["games_count"] >= min_games_threshold end)

      good_civs_list =
        civs_played_enough_list
        |> Enum.filter(fn civ -> civ["win_rate"] >= 50.0 end)

      good_civs_count = length(good_civs_list)

      # Playing only 1 civ well = not versatile at all
      if good_civs_count <= 1 do
        0.0
      else
        avg_wr =
          good_civs_list
          |> Enum.map(fn civ -> civ["win_rate"] end)
          |> Enum.sum()
          |> Kernel./(good_civs_count)

        # Diversity score with diminishing returns: 100 * (1 - 1/n)
        # 2 civs = 50, 3 civs = 66.7, 4 civs = 75, 5 civs = 80
        diversity_score = 100.0 * (1.0 - 1.0 / good_civs_count) * 1.15

        # Win rate multiplier with exponential scaling above 50%
        # Ladder systems force ~50% WR, so higher WRs deserve bigger rewards
        # 50% WR = 1.0x, 55% WR = 1.18x, 60% WR = 1.41x, 65% WR = 1.68x
        wr_multiplier = :math.pow(avg_wr / 50.0, 1.8)

        # Final score with cap at 100
        min(100.0, diversity_score * wr_multiplier)
      end
    end
  end

  defp calculate_versatility(_), do: @default_score_insufficient_data

  # Calculate win rate when facing higher-rated opponents
  # Uses standard deviation to determine what counts as "significantly higher rated"
  defp calculate_underdog_success(games_data)
       when is_list(games_data) and length(games_data) > 0 do
    if length(games_data) < 20 do
      @default_score_insufficient_data
    else
      # Calculate rating differences (opponent - player)
      rating_diffs =
        games_data
        |> Enum.filter(fn game ->
          get_in(game, ["player_rating"]) != nil and
            get_in(game, ["opponent_rating"]) != nil
        end)
        |> Enum.map(fn game ->
          opponent_rating = get_in(game, ["opponent_rating"])
          player_rating = get_in(game, ["player_rating"])
          opponent_rating - player_rating
        end)

      if length(rating_diffs) < 20 do
        @default_score_insufficient_data
      else
        # Calculate standard deviation of rating differences
        mean_diff = Enum.sum(rating_diffs) / length(rating_diffs)

        variance =
          rating_diffs
          |> Enum.map(fn diff -> :math.pow(diff - mean_diff, 2) end)
          |> Enum.sum()
          |> Kernel./(length(rating_diffs))

        std_dev = :math.sqrt(variance)

        # Define underdog threshold as mean + 0.75 * std_dev
        # This typically means opponent is meaningfully higher rated
        underdog_threshold = mean_diff + 0.75 * std_dev

        # Find games where we're the underdog and calculate win rate
        underdog_games =
          games_data
          |> Enum.filter(fn game ->
            opponent_rating = get_in(game, ["opponent_rating"])
            player_rating = get_in(game, ["player_rating"])

            opponent_rating != nil and player_rating != nil and
              opponent_rating - player_rating >= underdog_threshold
          end)

        if length(underdog_games) < 5 do
          @default_score_insufficient_data
        else
          underdog_wins =
            underdog_games
            |> Enum.count(fn game -> game["result"] == "win" end)

          underdog_win_rate = underdog_wins / length(underdog_games)
          underdog_win_rate * 100
        end
      end
    end
  end

  defp calculate_underdog_success(_), do: @default_score_insufficient_data

  def fetch_analysis(profile_id) do
    WololoWeb.SentryContext.set_player_context(profile_id)
    Logger.info("Fetching analysis for profile_id: #{profile_id}")

    with {:ok, player_data} <- PlayerStatsAPI.fetch_player_data(profile_id, false),
         {:ok, games_json} <- PlayerGamesAPI.get_players_games_statistics(profile_id, false) do
      Logger.info("Successfully fetched player data and games")
      rating_history = get_in(player_data, ["modes", "rm_solo", "rating_history"])
      civ_stats = get_in(player_data, ["modes", "rm_solo", "civilizations"]) || []

      # Process games for underdog success
      games_data = extract_games_with_opponent_rating(games_json, profile_id)

      Logger.info(
        "rating_history is_nil: #{is_nil(rating_history)}, is_map: #{is_map(rating_history)}"
      )

      if is_map(rating_history),
        do: Logger.info("rating_history size: #{map_size(rating_history)}")

      if is_nil(rating_history) or (is_map(rating_history) and map_size(rating_history) == 0) do
        Logger.warning(
          "No rating history available for profile_id: #{profile_id}, returning default scores"
        )

        %{
          peak_proximity: @default_score_insufficient_data,
          recovery: @default_score_insufficient_data,
          momentum: @default_score_insufficient_data,
          anti_tilt: @default_score_insufficient_data,
          pressure_performance: @default_score_insufficient_data,
          rating_efficiency: @default_score_insufficient_data,
          versatility: calculate_versatility(civ_stats),
          underdog_success: calculate_underdog_success(games_data)
        }
      else
        Logger.info("Calculating analysis metrics...")

        result = %{
          peak_proximity: calculate_peak_proximity(rating_history),
          recovery: calculate_recovery(rating_history),
          momentum: calculate_momentum(rating_history),
          anti_tilt: calculate_anti_tilt(rating_history),
          pressure_performance: calculate_pressure_performance(rating_history),
          rating_efficiency: calculate_rating_efficiency(rating_history),
          versatility: calculate_versatility(civ_stats),
          underdog_success: calculate_underdog_success(games_data)
        }

        Logger.info("Analysis complete: #{inspect(result)}")
        result
      end
    else
      {:error, reason} ->
        Logger.error("Failed to fetch player data: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp extract_games_with_opponent_rating(games_json, profile_id) do
    games_json
    |> Jason.decode!()
    |> Map.get("games", [])
    |> Enum.flat_map(fn game ->
      case PlayerGamesAPI.extract_player_opponent(game, profile_id) do
        {:ok, player, opponent} ->
          [%{
            "player_rating" => player["player"]["rating"],
            "opponent_rating" => opponent["player"]["rating"],
            "result" => if(player["player"]["result"] == "win", do: "win", else: "loss")
          }]

        {:error, _reason} ->
          # Skip games with invalid structure
          []
      end
    end)
  end
end
