defmodule Wololo.AgeupsFixtures do
  def patch, do: "test-patch"
  def dry_arabia_id, do: 163361

  def options do
    %{
      patch: patch(),
      patch_label: "Test Patch",
      raw: %{
        "filter" => %{
          "patch" => %{
            "default" => patch(),
            "options" => [%{"value" => patch(), "label" => "Test Patch"}]
          }
        }
      }
    }
  end

  def query_options_json do
    %{
      "filter" => %{
        "patch" => %{
          "default" => patch(),
          "options" => [%{"value" => patch(), "label" => "Test Patch"}]
        },
        "kind" => %{"default" => "rm_solo"},
        "civilization" => %{"default" => nil},
        "map_id" => %{
          "default" => nil,
          "options" => [%{"label" => "Dry Arabia", "value" => dry_arabia_id()}]
        }
      }
    }
  end

  def payload do
    %{
      "ageups_metadata" => [
        %{"pbgid" => 1, "icon" => "https://example.com/a.png", "name" => "School of Cavalry"},
        %{"pbgid" => 2, "icon" => "https://example.com/b.png", "name" => "Guild Hall"},
        %{"pbgid" => 3, "icon" => "https://example.com/c.png", "name" => "Red Palace"}
      ],
      "data" => %{
        "age1-4" => [
          complete_row("french", 58.5, 12_000, 1, "School of Cavalry", 2, "Guild Hall", 3, "Red Palace"),
          complete_row("french", 54.0, 30_000, 4, "Chamber of Commerce", 5, "Royal Institute", 3, "Red Palace"),
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
          complete_row("english", 55.0, 5000, 10, "Abbey of Kings", 11, "White Tower", 12, "Berkshire Palace")
        ]
      }
    }
  end

  def map_payload do
    %{
      "ageups_metadata" => [
        %{"pbgid" => 1, "icon" => "https://example.com/a.png", "name" => "School of Cavalry"},
        %{"pbgid" => 2, "icon" => "https://example.com/b.png", "name" => "Guild Hall"},
        %{"pbgid" => 3, "icon" => "https://example.com/c.png", "name" => "Red Palace"}
      ],
      "data" => %{
        "age1-4" => [
          complete_row(
            "french",
            62.0,
            400,
            4,
            "Chamber of Commerce",
            5,
            "Royal Institute",
            3,
            "Red Palace"
          ),
          complete_row("french", 50.0, 220, 1, "School of Cavalry", 2, "Guild Hall", 3, "Red Palace")
        ]
      }
    }
  end

  def matchups_json do
    %{
      "data" => [
        %{
          "opponent_civilization" => "english",
          "win_rate" => 61.0,
          "player_games_count" => 80,
          "win_count" => 49,
          "duration_average" => 1500
        }
      ]
    }
  end

  def civ_matchups_json do
    %{
      "data" => [
        %{
          "opponent_civilization" => "english",
          "win_rate" => 47.5,
          "player_games_count" => 800,
          "win_count" => 380,
          "duration_average" => 1500
        },
        %{
          "opponent_civilization" => "delhi_sultanate",
          "win_rate" => 52.2,
          "player_games_count" => 872,
          "win_count" => 455,
          "duration_average" => 1500
        }
      ]
    }
  end

  def complete_row(civ, wr, games, a2, n2, a3, n3, a4, n4) do
    %{
      "civilization" => civ,
      "win_rate" => wr,
      "player_games_count" => games,
      "win_count" => round(wr / 100 * games),
      "age2_pbgid" => a2,
      "age2_name" => n2,
      "age2_finished_at_average" => 280.0,
      "age3_pbgid" => a3,
      "age3_name" => n3,
      "age3_finished_at_average" => 800.0,
      "age4_pbgid" => a4,
      "age4_name" => n4,
      "age4_finished_at_average" => 1500.0
    }
  end
end
