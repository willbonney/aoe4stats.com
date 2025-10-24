defmodule Wololo.Utils do
  # Rank thresholds (promotion/demotion boundaries)
  @rank_thresholds [700, 800, 900, 1000, 1100, 1200, 1300, 1400, 1500, 1600]

  def get_rank_thresholds, do: @rank_thresholds

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
