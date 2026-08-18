defmodule Wololo.PlayerGamesAPITest do
  use ExUnit.Case, async: true

  alias Wololo.PlayerGamesAPI

  defp team(profile_id, attrs) do
    player =
      Map.merge(
        %{"profile_id" => profile_id, "rating" => 1400, "result" => "win", "country" => "fr"},
        attrs
      )

    [%{"player" => player}]
  end

  defp game(player_id, opponent_id, opponent_country, rating) do
    %{
      "updated_at" => "2026-01-01T00:00:00Z",
      "duration" => 1500,
      "teams" => [
        team(player_id, %{"rating" => rating, "result" => "win"}),
        team(opponent_id, %{"country" => opponent_country, "result" => "loss", "rating" => 1300})
      ]
    }
  end

  test "extract_player_opponent splits the two 1v1 teams" do
    game = game(42, 99, "de", 1410)
    assert {:ok, player, opponent} = PlayerGamesAPI.extract_player_opponent(game, 42)
    assert player["player"]["profile_id"] == 42
    assert opponent["player"]["country"] == "de"
    assert PlayerGamesAPI.extract_player_opponent(%{"teams" => []}, 42) ==
             {:error, :invalid_game_structure}
  end

  test "process_games builds country shares and rating points" do
    body =
      Jason.encode!(%{
        "games" => [
          game(42, 99, "de", 1400),
          game(42, 100, "de", 1410),
          game(42, 101, "us", 1420)
        ]
      })

    assert {:ok, %{countries: countries, ratings: ratings}} = PlayerGamesAPI.process_games(body, 42)
    assert countries["de"] == 66.7
    assert countries["us"] == 33.3
    assert length(ratings) == 3
    assert Enum.map(ratings, & &1.player_rating) == [1420, 1410, 1400]
  end

  test "process_games errors when there are no valid 1v1 games" do
    assert {:error, message} = PlayerGamesAPI.process_games(~s({"games":[]}), 42)
    assert message =~ "No 1v1 ranked games"
  end
end
