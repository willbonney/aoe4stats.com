defmodule Wololo.UtilsTest do
  use ExUnit.Case, async: true

  alias Wololo.Utils

  test "maps ratings onto league colors" do
    assert Utils.rating_to_color_map("N/A") == "#DDDDDD"
    assert Utils.rating_to_color_map(400) == "#B87333"
    assert Utils.rating_to_color_map(1600) == "#FF8C00"
    assert Utils.full_rating_to_color_map(720) == "#B87333"
    assert Utils.full_rating_to_color_map(1450) == "#FFB84D"
  end

  test "exposes rank thresholds and league ranges" do
    assert 1000 in Utils.get_rank_thresholds()
    assert Utils.get_league_ranges()["Gold"] == {900, 1050}
    assert Utils.get_league_ranges()["Conqueror"] == {1400, nil}
    assert Utils.get_league_colors()["Diamond"] == "#87CEFA"
    assert Utils.get_rank_buckets()._gte_1600 == "Conqueror III"
  end
end
