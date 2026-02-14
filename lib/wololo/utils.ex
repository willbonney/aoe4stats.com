defmodule Wololo.Utils do
  # Rank thresholds (promotion/demotion boundaries)
  @rank_thresholds [700, 800, 900, 1000, 1100, 1200, 1300, 1400, 1500, 1600]

  # Detailed rank buckets with tier names
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

  # Broad league ranges (min rating, max rating) - max is exclusive, nil means unbounded
  @league_ranges %{
    "Bronze" => {0, 750},
    "Silver" => {750, 900},
    "Gold" => {900, 1050},
    "Platinum" => {1050, 1200},
    "Diamond" => {1200, 1400},
    "Conqueror" => {1400, nil}
  }

  # League colors matching full_rating_to_color_map (for use in JS via API or templates)
  @league_colors %{
    "Bronze" => "#B87333",
    "Silver" => "#C0C0C0",
    "Gold" => "#FFC125",
    "Platinum" => "#E6E6E6",
    "Diamond" => "#87CEFA",
    "Conqueror" => "#FFA500"
  }

  def get_rank_thresholds, do: @rank_thresholds
  def get_rank_buckets, do: @rank_buckets
  def get_league_ranges, do: @league_ranges
  def get_league_colors, do: @league_colors

  def rating_to_color_map(rating) do
    cond do
      rating == "N/A" -> "#DDDDDD"
      rating <= 499 -> "#B87333"
      rating <= 699 -> "#C0C0C0"
      rating <= 999 -> "#FFC125"
      rating <= 1199 -> "#E6E6E6"
      rating <= 1399 -> "#87CEEB"
      true -> "#FF8C00"
    end
  end

  def full_rating_to_color_map(rating) do
    cond do
      rating == "N/A" -> "#DDDDDD"
      rating < 700 -> "#C18A4A"
      rating < 750 -> "#B87333"
      rating < 800 -> "#A65C22"
      rating < 850 -> "#D0D0D0"
      rating < 900 -> "#C0C0C0"
      rating < 950 -> "#B8B8B8"
      rating < 1000 -> "#FFD700"
      rating < 1050 -> "#FFC125"
      rating < 1100 -> "#E6B800"
      rating < 1150 -> "#F0F4F8"
      rating < 1200 -> "#E6E6E6"
      rating < 1250 -> "#D4DCE6"
      rating < 1300 -> "#9FD4E8"
      rating < 1350 -> "#87CEFA"
      rating < 1400 -> "#7BB8FF"
      rating < 1500 -> "#FFB84D"
      rating < 1600 -> "#FFA500"
      true -> "#F2991A"
    end
  end
end
