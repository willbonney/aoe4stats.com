defmodule Wololo.Utils do
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
      # Bronze I - Light Brown
      rating < 700 -> "#B87333"
      # Bronze II - Medium Brown
      rating < 750 -> "#A0522D"
      # Bronze III - Dark Brown
      rating < 800 -> "#8B4513"
      # Silver I - Light Silver
      rating < 850 -> "#D3D3D3"
      # Silver II - Medium Silver
      rating < 900 -> "#C0C0C0"
      # Silver III - Dark Silver
      rating < 950 -> "#A8A8A8"
      # Gold I - Light Gold
      rating < 1000 -> "#FFD700"
      # Gold II - Medium Gold
      rating < 1050 -> "#FFC125"
      # Gold III - Dark Gold
      rating < 1100 -> "#DAA520"
      # Platinum I - Light Platinum
      rating < 1150 -> "#F0F8FF"
      # Platinum II - Medium Platinum
      rating < 1200 -> "#E6E6E6"
      # Platinum III - Dark Platinum
      rating < 1250 -> "#B0C4DE"
      # Diamond I - Light Diamond (Sky Blue)
      rating < 1300 -> "#B0E0E6"
      # Diamond II - Medium Diamond
      rating < 1350 -> "#87CEFA"
      # Diamond III - Dark Diamond
      rating < 1400 -> "#87CEEB"
      # Conqueror I - Light Conqueror (Orange)
      rating < 1500 -> "#FFB347"
      # Conqueror II - Medium Conqueror
      rating < 1600 -> "#FFA500"
      # Conqueror III - Dark Conqueror
      true -> "#FF8C00"
    end
  end
end
