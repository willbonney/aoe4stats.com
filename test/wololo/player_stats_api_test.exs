defmodule Wololo.PlayerStatsAPITest do
  use ExUnit.Case, async: true

  alias Wololo.PlayerStatsAPI

  test "process_player_stats derives rating and rank history" do
    body =
      Jason.encode!(%{
        "modes" => %{
          "rm_solo" => %{
            "max_rating" => 1600,
            "max_rating_7d" => 1580,
            "max_rating_1m" => 1550,
            "season" => 10,
            "rank" => 40,
            "civilizations" => [],
            "previous_seasons" => [
              %{"season" => 8, "rank" => 80},
              %{"season" => 9, "rank" => 60}
            ],
            "rating_history" => %{
              "1" => %{"rating" => 1500},
              "2" => %{"rating" => 1540}
            }
          }
        }
      })

    stats = PlayerStatsAPI.process_player_stats(body)
    assert stats.max_rating == 1600
    assert stats.total_count == 2
    assert stats.average_rating == 1520
    assert stats.total_seasons == 3
    assert stats.average_rank == 47
    assert stats.min_rank == 80
    assert stats.max_rank == 60
    assert stats.rating_spread > 0
  end

  test "rating helpers handle empty histories" do
    assert PlayerStatsAPI.calculate_average_rating(%{}, 0) == 0
    assert PlayerStatsAPI.calculate_average_rank([], 0) == 0
    assert PlayerStatsAPI.calculate_rating_spread(%{}) == 0.0
    assert PlayerStatsAPI.process_player_stats("not-json") == %{error: "Invalid data structure"}
  end
end
