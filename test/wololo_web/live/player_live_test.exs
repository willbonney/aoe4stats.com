defmodule WololoWeb.PlayerLiveTest.HTTPStub do
  def get_with_retry(url, _headers \\ [], _retries \\ 0) do
    body =
      if String.contains?(url, "full_history=true") do
        %{
          "modes" => %{
            "rm_solo" => %{
              "max_rating" => 1600,
              "max_rating_7d" => 1500,
              "max_rating_1m" => 1500,
              "season" => 10,
              "rank" => 40,
              "civilizations" => [],
              "previous_seasons" => [
                %{"season" => 8, "rank" => 80},
                %{"season" => 9, "rank" => 60}
              ],
              "rating_history" => %{"1" => %{"rating" => 1500, "streak" => 1}}
            }
          }
        }
      else
        %{
          "name" => "Beastyqt",
          "country" => "us",
          "site_url" => "https://aoe4world.com/players/42",
          "modes" => %{"rm_solo" => %{"rank" => 12, "win_rate" => 58.2}}
        }
      end

    {:ok, Jason.encode!(body)}
  end
end

defmodule WololoWeb.PlayerLiveTest do
  use WololoWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  setup do
    Cachex.del(:wololo_cache, :leaderboard_data)
    previous = Application.get_env(:wololo, :http_client)
    Application.put_env(:wololo, :http_client, WololoWeb.PlayerLiveTest.HTTPStub)

    on_exit(fn ->
      if previous do
        Application.put_env(:wololo, :http_client, previous)
      else
        Application.delete_env(:wololo, :http_client)
      end
    end)

    :ok
  end

  test "country codes become flag emoji" do
    assert WololoWeb.PlayerLive.get_country_code_emoji("us") == "🇺🇸"
    assert WololoWeb.PlayerLive.get_country_code_emoji(nil) == nil
  end

  test "player header and rank history load from the API", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/player/42/rank")
    html = render(view)

    assert html =~ "Beastyqt"
    assert html =~ "rank #12"
    assert html =~ "wr 58.2 %"

    html = render_async(view)
    assert html =~ "Highest"
    assert html =~ "#60"
    assert html =~ "#80"
    assert html =~ "#70"
  end

  test "a cached leaderboard row fills the first HTML response", %{conn: conn} do
    Cachex.put(:wololo_cache, :leaderboard_data, [
      %{
        profile_id: "42",
        name: "Cached Name",
        rank: 4,
        rating: 1900,
        country: "de",
        games_count: 10,
        wins_count: 7
      }
    ])

    html = html_response(get(conn, ~p"/player/42"), 200)
    assert html =~ "Cached Name"
    assert html =~ "rank #4"
    assert html =~ "wr 70.0 %"
  end
end
