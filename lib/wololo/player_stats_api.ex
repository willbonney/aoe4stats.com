defmodule Wololo.PlayerStatsAPI do
  require Logger

  @base_url Application.compile_env(:wololo, :api_base_url)

  @rank_buckets %{
    _gte_1600: "Conqueror III",
    _1500_to_1599: "Conqueror II",
    _1400_to_1499: "Conqueror I",
    _1350_to_1399: "Diamond III",
    _1300_to_1349: "Diamond II",
    _1200_to_1299: "Diamond I",
    _1150_to_1199: "Platinum III",
    _1100_to_1149: "Platinum II",
    _1050_to_1099: "Platinum I",
    _1000_to_1049: "Gold III",
    _950_to_999: "Gold II",
    _900_to_949: "Gold I",
    _850_to_899: "Silver III",
    _800_to_849: "Silver II",
    _750_to_799: "Silver I",
    _700_to_749: "Bronze III",
    _650_to_699: "Bronze II",
    _lt_650: "Bronze I"
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
    with {:ok, data} <- Jason.decode(body) do
      rating_history = get_in(data, ["modes", "rm_solo", "rating_history"])
      previous_seasons = get_in(data, ["modes", "rm_solo", "previous_seasons"])
      _current_rank = get_in(data, ["modes", "rm_solo", "rank"])
      current_season = get_in(data, ["modes", "rm_solo", "season"])
      civ_stats = get_in(data, ["modes", "rm_solo", "civilizations"])

      total_count = if is_map(rating_history), do: map_size(rating_history), else: 0

      # Build rank_history and total_seasons only if we have previous_seasons data
      {rank_history, total_seasons} =
        if is_list(previous_seasons) and is_integer(current_season) do
          seasons_count = Enum.count(previous_seasons) + 1

          history =
            Enum.reduce(
              previous_seasons,
              [],
              fn season, acc ->
                if season["rank"] != nil do
                  [
                    %{
                      rank: season["rank"],
                      season: season["season"]
                    }
                    | acc
                  ]
                else
                  acc
                end
              end
            )
            |> Enum.reverse()

          {history, seasons_count}
        else
          {[], 0}
        end

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
        rating_spread: calculate_rating_spread(rating_history),
        min_rank:
          if(length(rank_history) > 0,
            do: Enum.max_by(rank_history, fn %{rank: rank} -> rank end).rank,
            else: nil
          ),
        max_rank:
          if(length(rank_history) > 0,
            do: Enum.min_by(rank_history, fn %{rank: rank} -> rank end).rank,
            else: nil
          ),
        percentage_time_in_rank:
          if(is_map(rating_history), do: get_percentage_time_in_rank(rating_history), else: nil),
        civ_stats: civ_stats
      }
    else
      error ->
        Logger.error("Jason decode failed: #{inspect(error)}")
        %{error: "Invalid data structure"}
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

  def calculate_rating_spread(rating_history)
      when is_map(rating_history) and map_size(rating_history) > 1 do
    ratings =
      rating_history
      |> Enum.map(fn {_, %{"rating" => rating}} -> rating end)
      |> Enum.reject(&is_nil/1)

    if length(ratings) > 1 do
      mean = Enum.sum(ratings) / length(ratings)

      variance =
        ratings
        |> Enum.map(fn rating -> :math.pow(rating - mean, 2) end)
        |> Enum.sum()
        |> Kernel./(length(ratings))

      :math.sqrt(variance) |> Float.round(1)
    else
      0.0
    end
  end

  def calculate_rating_spread(_), do: 0.0

  def get_percentage_time_in_rank(rating_history) do
    # Sort by timestamp (key) to ensure chronological order, then skip first 5 entries (placement matches)
    rating_entries =
      rating_history
      |> Enum.sort_by(fn {timestamp, _} -> timestamp end)
      |> Enum.drop(5)

    total_count = length(rating_entries)

    Enum.into(@rank_buckets, %{}, fn {rank_bucket, rank_name} ->
      count =
        Enum.count(rating_entries, fn {_, %{"rating" => rating}} ->
          get_rank_bucket(rating) == rank_bucket
        end)

      percentage = if total_count > 0, do: count / total_count * 100, else: 0

      # Get the representative rating for this bucket to determine color
      representative_rating = get_representative_rating(rank_bucket)
      color = Wololo.Utils.full_rating_to_color_map(representative_rating)

      {rank_name, %{percentage: percentage, color: color}}
    end)
  end

  defp get_rank_bucket(rating) do
    cond do
      rating >= 1600 -> :_gte_1600
      rating >= 1500 -> :_1500_to_1599
      rating >= 1400 -> :_1400_to_1499
      rating >= 1350 -> :_1350_to_1399
      rating >= 1300 -> :_1300_to_1349
      rating >= 1200 -> :_1200_to_1299
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
      rating >= 650 -> :_650_to_699
      true -> :_lt_650
    end
  end

  defp get_representative_rating(rank_bucket) do
    # Extract the rating range from the atom name and calculate the middle
    case rank_bucket do
      :_gte_1600 -> 1650
      :_1500_to_1599 -> 1550
      :_1400_to_1499 -> 1450
      :_1350_to_1399 -> 1375
      :_1300_to_1349 -> 1325
      :_1200_to_1299 -> 1250
      :_1150_to_1199 -> 1175
      :_1100_to_1149 -> 1125
      :_1050_to_1099 -> 1075
      :_1000_to_1049 -> 1025
      :_950_to_999 -> 975
      :_900_to_949 -> 925
      :_850_to_899 -> 875
      :_800_to_849 -> 825
      :_750_to_799 -> 775
      :_700_to_749 -> 725
      :_650_to_699 -> 675
      :_lt_650 -> 625
    end
  end
end
