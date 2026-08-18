defmodule Wololo.CivsByMapAPITest do
  use ExUnit.Case, async: true

  alias Wololo.CivsByMapAPI

  test "transform_data builds per-civ win rates for each map" do
    raw = %{
      "data" => [
        %{
          "map" => "Dry Arabia",
          "games_count" => 1000,
          "civilizations" => %{
            "french" => %{"win_rate" => 51.655, "games_count" => 200},
            "english" => %{"win_rate" => 48.1, "games_count" => 180}
          }
        }
      ]
    }

    [map] = CivsByMapAPI.transform_data(raw)
    assert map.name == "Dry Arabia"
    assert map.civs.french.win_rate == "51.66%"
    assert map.civs.french.games_count == 200
    assert map.civs.english.win_rate == "48.10%"
    assert map.civs.delhi_sultanate.win_rate == "N/A"
  end

  test "transform_data skips invalid payloads" do
    assert CivsByMapAPI.transform_data(%{}) == []
    assert CivsByMapAPI.transform_data(%{"data" => [%{"map" => "Nope"}]}) == [
             %{name: "Unknown", error: "Invalid data structure"}
           ]
  end
end
