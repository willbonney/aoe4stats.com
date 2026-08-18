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

      if should_process do
        case process_games(Jason.encode!(data), profile_id) do
          {:ok, processed_data} -> {:ok, processed_data}
          {:error, reason} -> {:error, reason}
        end
      else
        {:ok, Jason.encode!(data)}
      end
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

  # Extract player and opponent data from a game
  # Returns {:ok, player_data, opponent_data} or {:error, reason}
  def extract_player_opponent(game, profile_id) do
    teams = game["teams"]
    profile_id = to_string(profile_id)

    if is_list(teams) do
      {player_team, opponent_team} =
        Enum.split_with(teams, fn
          [team | _] when is_map(team) ->
            to_string(get_in(team, ["player", "profile_id"])) == profile_id

          _ ->
            false
        end)

      case {player_team, opponent_team} do
        {[[player]], [[opponent]]} ->
          {:ok, player, opponent}

        _ ->
          {:error, :invalid_game_structure}
      end
    else
      {:error, :invalid_game_structure}
    end
  rescue
    _ -> {:error, :invalid_game_structure}
  end

  def process_games(body, profile_id) do
    games =
      body
      |> Jason.decode!()
      |> Map.get("games")
      |> Enum.reverse()

    if Enum.empty?(games) do
      {:error, "No 1v1 ranked games found for this player. They may not have played enough games this season."}
    else
      result =
        games
        |> Enum.reduce(%{countries: %{}, ratings: [], valid_games: 0}, fn game, acc ->
          case extract_player_opponent(game, profile_id) do
            {:ok, player, opponent} ->
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
                      moving_average_10g: 0,
                      moving_average_20g: 0,
                      moving_average_30g: 0
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
                            moving_average_10g: get_moving_average(ratings, 10),
                            moving_average_20g: get_moving_average(ratings, 20),
                            moving_average_30g: get_moving_average(ratings, 30)
                          }
                        ]
                    end
                  end
                )

              Map.update(acc, :valid_games, 1, &(&1 + 1))

            {:error, _reason} ->
              # Skip games with invalid structure (e.g., team games mistakenly included)
              acc
          end
        end)

      if result[:valid_games] == 0 do
        {:error, "No valid 1v1 ranked games found for this player. They may not have played enough games this season."}
      else
        %{countries: countries, ratings: ratings} = result
        valid_games_count = result[:valid_games]

        # Convert raw counts to percentages
        countries_percentages =
          countries
          |> Enum.map(fn {country, count} ->
            {country, Float.round(count / valid_games_count * 100, 1)}
          end)
          |> Enum.into(%{})

        {:ok, %{countries: countries_percentages, ratings: ratings}}
      end
    end
  end

  defp count_games_by_length(games) do
    Enum.reduce(games, @game_length_buckets, fn game, acc ->
      bucket = get_duration_bucket(game["duration"])
      Map.update(acc, bucket, 1, &(&1 + 1))
    end)
  end

  defp count_wins_by_game_length(games, profile_id) do
    Enum.reduce(games, @game_length_buckets, fn game, acc ->
      case extract_player_opponent(game, profile_id) do
        {:ok, player, _opponent} ->
          won = if player["player"]["result"] == "win", do: 1, else: 0
          bucket = get_duration_bucket(game["duration"])
          Map.update(acc, bucket, won, &(&1 + won))

        {:error, _} ->
          acc
      end
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
