defmodule Wololo.PlayerStatsAPI do
  require Logger

  @base_url Application.compile_env(:wololo, :api_base_url)

  @rank_buckets %{
    _gte_1600: "Conqueror III",
    _1500_to_1599: "Conqueror II",
    _1400_to_1499: "Conqueror I",
    _1350_to_1399: "Diamond III",
    _1300_to_1349: "Diamond II",
    _1250_to_1299: "Diamond I",
    _1200_to_1249: "Platinum III",
    _1150_to_1199: "Platinum II",
    _1100_to_1149: "Platinum I",
    _1050_to_1099: "Gold III",
    _1000_to_1049: "Gold II",
    _950_to_999: "Gold I",
    _900_to_949: "Silver III",
    _850_to_899: "Silver II",
    _800_to_849: "Silver I",
    _750_to_799: "Bronze III",
    _700_to_749: "Bronze II",
    _lt_700: "Bronze I"
  }

  def fetch_player_data(profile_id, with_stats \\ false) do
    endpoint = "#{@base_url}/players/#{profile_id}?full_history=true"

    case Wololo.HTTPClient.get_with_retry(endpoint) do
      {:ok, body} ->
        {:ok, if(with_stats, do: process_player_stats(body), else: Jason.decode!(body))}

      {:error, reason} ->
        {:error, "fetch_player_data failed: #{reason}"}
    end
  end

  def process_player_stats(body) do
    with {:ok, data} <- Jason.decode(body),
         rating_history when is_map(rating_history) <-
           get_in(data, ["modes", "rm_solo", "rating_history"]),
         previous_seasons when is_list(previous_seasons) <-
           get_in(data, ["modes", "rm_solo", "previous_seasons"]),
         current_rank when is_integer(current_rank) <- get_in(data, ["modes", "rm_solo", "rank"]),
         current_season when is_integer(current_season) <-
           get_in(data, ["modes", "rm_solo", "season"]) do
      total_count = Enum.count(rating_history)
      total_seasons = Enum.count(previous_seasons) + 1

      rank_history =
        Enum.map(previous_seasons, fn season ->
          %{
            rank: season["rank"],
            season: season["season"]
          }
        end)
        |> List.insert_at(0, %{rank: current_rank, season: current_season})

      %{
        max_rating: get_in(data, ["modes", "rm_solo", "max_rating"]) || "N/A",
        max_rating_7d: get_in(data, ["modes", "rm_solo", "max_rating_7d"]) || "N/A",
        max_rating_1m: get_in(data, ["modes", "rm_solo", "max_rating_1m"]) || "N/A",
        average_rating:
          if(total_count > 0,
            do: calculate_average_rating(rating_history, total_count),
            else: "N/A"
          ),
        total_count: total_count,
        rank_history: rank_history,
        total_seasons: total_seasons,
        average_rank:
          if(total_seasons > 0,
            do: calculate_average_rank(rank_history, total_seasons),
            else: "N/A"
          ),
        min_rank: Enum.max_by(rank_history, fn %{rank: rank} -> rank end).rank,
        max_rank: Enum.min_by(rank_history, fn %{rank: rank} -> rank end).rank,
        percentage_time_in_rank: get_percentage_time_in_rank(rating_history) || []
      }
    else
      _ -> %{error: "Invalid data structure"}
    end
  end

  def calculate_average_rating(rating_history, total_count) when total_count > 0 do
    round(
      Enum.reduce(rating_history, 0, fn {_, %{"rating" => rating}}, acc ->
        acc + (rating || 0)
      end) / total_count
    )
  end

  # Handle zero count case
  def calculate_average_rating(_, _), do: 0

  def calculate_average_rank(rank_history, total_count) when total_count > 0 do
    round(
      Enum.reduce(rank_history, 0, fn %{rank: rank}, acc ->
        acc + (rank || 0)
      end) / total_count
    )
  end

  # Handle zero count case
  def calculate_average_rank(_, _), do: 0

  def get_percentage_time_in_rank(rating_history) do
    Enum.map(@rank_buckets, fn {rank_bucket, _} ->
      count =
        Enum.count(rating_history, fn {_, %{"rating" => rating}} ->
          get_rank_bucket(rating) == rank_bucket
        end)

      percentage = count / length(rating_history) * 100
      {rank_bucket, percentage}
    end)
  end

  defp get_rank_bucket(rating) do
    cond do
      rating >= 1600 -> :_gte_1600
      rating >= 1500 -> :_1500_to_1599
      rating >= 1400 -> :_1400_to_1499
      rating >= 1350 -> :_1350_to_1399
      rating >= 1300 -> :_1300_to_1349
      rating >= 1250 -> :_1250_to_1299
      rating >= 1200 -> :_1200_to_1249
      rating >= 1150 -> :_1150_to_1199
      rating >= 1100 -> :_1100_to_1149
      rating >= 1050 -> :_1050_to_1099
      rating >= 1000 -> :_1000_to_1049
      rating >= 950 -> :_950_to_999
      rating >= 900 -> :_900_to_949
      rating >= 850 -> :_850_to_899
      rating >= 800 -> :_800_to_849
      rating >= 750 -> :_750_to_799
      rating >= 700 -> :_700_to_749
      true -> :_lt_700
    end
  end
end
