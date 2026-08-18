defmodule Wololo.MatchupsAndMetaTest do
  use ExUnit.Case, async: true

  alias Wololo.CivsMetaAPI
  alias Wololo.AgeupsAPI
  alias WololoWeb.CivHelpers

  test "formats duration as whole minutes" do
    assert CivHelpers.format_duration(1589) == "26m"
    assert CivHelpers.format_duration(nil) == nil
  end

  test "transforms civ meta points" do
    raw = %{
      "data" => [
        %{
          "civilization" => "english",
          "win_rate" => 47.1,
          "pick_rate" => 12.6,
          "games_count" => 2000
        }
      ]
    }

    [point] = CivsMetaAPI.transform_data(raw)
    assert point.label == "English"
    assert point.win_rate == 47.1
    assert point.pick_rate == 12.6
  end

  test "parses complete landmark paths and picks the winningest one" do
    raw = %{
      "ageups_metadata" => [
        %{"pbgid" => 1, "icon" => "https://example.com/a.png", "name" => "School of Cavalry"},
        %{"pbgid" => 2, "icon" => "https://example.com/b.png", "name" => "Guild Hall"},
        %{"pbgid" => 3, "icon" => "https://example.com/c.png", "name" => "Red Palace"}
      ],
      "data" => %{
        "age1-4" => [
          %{
            "civilization" => "french",
            "win_rate" => 65.0,
            "player_games_count" => 40,
            "win_count" => 26,
            "age2_pbgid" => 9,
            "age2_name" => "Rare Landmark",
            "age3_pbgid" => 8,
            "age3_name" => "Rare Castle",
            "age4_pbgid" => 7,
            "age4_name" => "Rare Imp"
          },
          %{
            "civilization" => "french",
            "win_rate" => 58.5,
            "player_games_count" => 12000,
            "win_count" => 7020,
            "age2_pbgid" => 1,
            "age2_name" => "School of Cavalry",
            "age2_finished_at_average" => 283.0,
            "age3_pbgid" => 2,
            "age3_name" => "Guild Hall",
            "age3_finished_at_average" => 803.0,
            "age4_pbgid" => 3,
            "age4_name" => "Red Palace",
            "age4_finished_at_average" => 1510.0
          },
          %{
            "civilization" => "french",
            "win_rate" => 54.0,
            "player_games_count" => 30000,
            "win_count" => 16200,
            "age2_pbgid" => 4,
            "age2_name" => "Chamber of Commerce",
            "age3_pbgid" => 5,
            "age3_name" => "Royal Institute",
            "age4_pbgid" => 3,
            "age4_name" => "Red Palace"
          },
          %{
            "civilization" => "french",
            "win_rate" => 51.0,
            "player_games_count" => 8000,
            "age2_pbgid" => 1,
            "age2_name" => "School of Cavalry",
            "age3_pbgid" => nil,
            "age3_name" => nil,
            "age4_pbgid" => nil,
            "age4_name" => nil
          },
          %{
            "civilization" => "english",
            "win_rate" => 90.0,
            "player_games_count" => 5000,
            "age2_pbgid" => 1,
            "age2_name" => "Abbey of Kings",
            "age3_pbgid" => 2,
            "age3_name" => "White Tower",
            "age4_pbgid" => 3,
            "age4_name" => "Berkshire Palace"
          }
        ]
      }
    }

    by_civ = AgeupsAPI.parse_all_paths(raw)
    assert Map.keys(by_civ) -- ["french", "english"] == []
    assert length(by_civ["english"]) == 1

    paths = AgeupsAPI.parse_paths(raw, "french")
    assert length(paths) == 3

    rec = AgeupsAPI.recommend(paths)
    assert rec.path.age2.name == "School of Cavalry"
    assert rec.path.age3.name == "Guild Hall"
    assert rec.path.age4.name == "Red Palace"
    assert rec.path.age2.icon == "https://example.com/a.png"
    assert rec.path.win_rate == 58.5
    assert hd(rec.alternatives).age2.name == "Chamber of Commerce"
  end

  test "recommends the path that is strongest against a selected opponent" do
    popular = %{
      civilization: "french",
      win_rate: 58.5,
      games: 12000,
      wins: 7020,
      duration_average: 1500,
      age2: %{age: 2, name: "School of Cavalry", pbgid: 1, icon: nil, finished_at: 280},
      age3: %{age: 3, name: "Guild Hall", pbgid: 2, icon: nil, finished_at: 800},
      age4: %{age: 4, name: "Red Palace", pbgid: 3, icon: nil, finished_at: 1500}
    }

    counter = %{
      civilization: "french",
      win_rate: 52.0,
      games: 4000,
      wins: 2080,
      duration_average: 1600,
      age2: %{age: 2, name: "Chamber of Commerce", pbgid: 4, icon: nil, finished_at: 310},
      age3: %{age: 3, name: "Royal Institute", pbgid: 5, icon: nil, finished_at: 820},
      age4: %{age: 4, name: "Red Palace", pbgid: 3, icon: nil, finished_at: 1480}
    }

    matchups = %{
      AgeupsAPI.path_key(popular) => [
        %{opponent: "english", win_rate: 48.0, games: 200, wins: 96, duration_average: 1400}
      ],
      AgeupsAPI.path_key(counter) => [
        %{opponent: "english", win_rate: 61.0, games: 80, wins: 49, duration_average: 1550}
      ]
    }

    rec = AgeupsAPI.recommend([popular, counter], opponent: "english", matchups: matchups)
    assert rec.path.age2.name == "Chamber of Commerce"
    assert rec.matchup.win_rate == 61.0
    assert hd(rec.alternatives).age2.name == "School of Cavalry"
    assert hd(rec.alternatives).win_rate == 48.0
    assert hd(rec.alternatives).games == 200

    patch = "test-#{System.unique_integer([:positive])}"
    AgeupsAPI.cache_recommendations(%{"french" => [popular, counter]}, patch)
    assert {:ok, cached} = AgeupsAPI.recommend_for("french", nil, patch)
    assert cached.path.age2.name == "School of Cavalry"
    assert {:ok, again} = AgeupsAPI.cached_recommendation("french", nil, patch)
    assert again.path.age2.name == "School of Cavalry"
  end

  test "formats landmark timing as a clock" do
    assert AgeupsAPI.format_clock(283) == "4:43"
    assert AgeupsAPI.format_clock(nil) == nil
  end

  test "slugs map names for icon files" do
    assert WololoWeb.LandmarksLive.map_slug("Golden Heights") == "golden_heights"
    assert WololoWeb.LandmarksLive.map_slug("King of the Hill") == "king_of_the_hill"
    assert WololoWeb.LandmarksLive.map_icon(%{name: "Golden Heights", slug: "golden_heights"}) ==
             "/images/maps/golden_heights.png"
  end
end
