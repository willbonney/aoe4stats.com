defmodule Wololo.PlayerGamesAPI do
  require Logger

  @base_url Application.compile_env(:wololo, :api_base_url)
  @game_length_buckets %{
    _lt_600: 0,
    _600_to_899: 0,
    _900_to_1199: 0,
    _1200_to_1499: 0,
    _1500_to_1799: 0,
    _1800_to_2699: 0,
    _2700_to_3599: 0,
    _gte3600: 0
  }

  defp get_moving_average(ratings, games_count) do
    current_index = length(ratings)
    games_count_minus_one = games_count - 1

    if length(ratings) <= games_count do
      nil
    else
      prev_x_ratings =
        if current_index >= games_count_minus_one do
          Enum.take(ratings, -games_count)
        else
          []
        end

      Enum.reduce(prev_x_ratings, 0, fn %{player_rating: rating}, acc ->
        acc + rating
      end) / games_count
    end
  end

  def get_player_wr_by_game_length(profile_id) do
    case get_players_games_statistics(profile_id, false) do
      {:ok, game_stats} ->
        games = Jason.decode!(game_stats)["games"]

        games_by_length = count_games_by_length(games)

        wins_by_game_length = count_wins_by_game_length(games, profile_id)

        {:ok,
         Enum.into(@game_length_buckets, %{}, fn {bucket, _} ->
           wins = Map.get(wins_by_game_length, bucket, 0)

           total_games = Map.get(games_by_length, bucket, 0)

           win_rate = if total_games > 0, do: wins / total_games * 100, else: 0
           {bucket, win_rate}
         end)}

      {:error, reason} ->
        Logger.error("Failed to get player games statistics: #{reason}")
        {:error, "Failed to retrieve player data"}
    end
  end

  def get_players_games_statistics(profile_id, should_process \\ true) do
    base_endpoint = "#{@base_url}/players/#{profile_id}/games?leaderboard=rm_solo"

    with {:ok, page1_data} <- fetch_page(base_endpoint, 1) do
      # Only fetch page 2 if there are more than 50 games (games per page)
      data =
        if page1_data["total"] > 50 do
          case fetch_page(base_endpoint, 2) do
            {:ok, page2_data} ->
              merge_page_data(page1_data, page2_data)

            {:error, _} ->
              # If page 2 fails, just use page 1 data
              page1_data
          end
        else
          page1_data
        end

      processed_data =
        if should_process do
          process_games(Jason.encode!(data), profile_id)
        else
          Jason.encode!(data)
        end

      {:ok, processed_data}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp fetch_page(base_endpoint, page) do
    endpoint = "#{base_endpoint}&page=#{page}"

    case Wololo.HTTPClient.get_with_retry(endpoint) do
      {:ok, body} ->
        {:ok, Jason.decode!(body)}

      {:error, reason} ->
        {:error, "player_games_api fetch_page failed: #{reason}"}
    end
  end

  defp merge_page_data(page1_data, page2_data) do
    %{
      "games" => page1_data["games"] ++ page2_data["games"],
      "total" => page1_data["total"]
    }
  end

  @type country_percentage :: {String.t(), float()}
  @type game_rating :: %{
          player_rating: integer() | nil,
          updated_at: String.t(),
          moving_average_5g: float(),
          moving_average_10g: float(),
          moving_average_20g: float()
        }
  @type processed_games :: %{
          countries: %{String.t() => float()},
          ratings: [game_rating()]
        }

  @spec process_games(String.t(), String.t()) :: processed_games()
  def process_games(body, profile_id) do
    games =
      body
      |> Jason.decode!()
      |> Map.get("games")
      |> Enum.reverse()

    result =
      games
      |> Enum.reduce(%{countries: %{}, ratings: []}, fn game, acc ->
        {player_team, opponent_team} =
          Enum.split_with(game["teams"], fn [team | _] ->
            to_string(team["player"]["profile_id"]) == profile_id
          end)

        [[opponent]] = opponent_team
        [[player]] = player_team
        opponent_country = opponent["player"]["country"]

        acc =
          if acc[:countries][opponent_country] == nil do
            # Initialize counter for this country
            update_in(acc, [:countries], &Map.put(&1, opponent_country, 1))
          else
            update_in(
              acc,
              [:countries],
              &Map.update(&1, opponent_country, 1, fn count -> count + 1 end)
            )
          end

        player_rating = player["player"]["rating"]
        updated_at = game["updated_at"]

        acc =
          Map.update(
            acc,
            :ratings,
            [
              %{
                player_rating: player_rating,
                updated_at: updated_at,
                moving_average_5g: 0,
                moving_average_10g: 0,
                moving_average_20g: 0
              }
            ],
            fn ratings ->
              if player_rating == nil do
                ratings
              else
                ratings ++
                  [
                    %{
                      player_rating: player_rating,
                      updated_at: updated_at,
                      moving_average_5g: get_moving_average(ratings, 5),
                      moving_average_10g: get_moving_average(ratings, 10),
                      moving_average_20g: get_moving_average(ratings, 20)
                    }
                  ]
              end
            end
          )

        acc
      end)
      |> then(fn %{countries: countries, ratings: ratings} ->
        # Convert raw counts to percentages
        countries_percentages =
          countries
          |> Enum.map(fn {country, count} ->
            {country, Float.round(count / length(games) * 100, 1)}
          end)
          |> Enum.into(%{})

        %{countries: countries_percentages, ratings: ratings}
      end)
  end

  defp count_games_by_length(games) do
    Enum.reduce(games, @game_length_buckets, fn game, acc ->
      bucket = get_duration_bucket(game["duration"])
      Map.update(acc, bucket, 1, &(&1 + 1))
    end)
  end

  defp count_wins_by_game_length(games, profile_id) do
    Enum.reduce(games, @game_length_buckets, fn game, acc ->
      {player_team, _} =
        Enum.split_with(game["teams"], fn [team | _] ->
          to_string(team["player"]["profile_id"]) == profile_id
        end)

      [[player]] = player_team
      won = if player["player"]["result"] == "win", do: 1, else: 0
      bucket = get_duration_bucket(game["duration"])

      Map.update(acc, bucket, won, &(&1 + won))
    end)
  end

  defp get_duration_bucket(duration) do
    cond do
      duration < 600 -> :_lt_600
      duration < 900 -> :_600_to_899
      duration < 1200 -> :_900_to_1199
      duration < 1500 -> :_1200_to_1499
      duration < 1800 -> :_1500_to_1799
      duration < 2700 -> :_1800_to_2699
      duration < 3600 -> :_2700_to_3599
      true -> :_gte3600
    end
  end
end
