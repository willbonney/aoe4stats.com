defmodule Wololo.PlayerGamesAPITest.HTTPStub do
  def start(pages) do
    state = %{pages: pages, requests: []}

    case Agent.start_link(fn -> state end, name: __MODULE__) do
      {:ok, pid} ->
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        Agent.update(pid, fn _ -> state end)
        {:ok, pid}
    end
  end

  def stop do
    case Process.whereis(__MODULE__) do
      pid when is_pid(pid) ->
        try do
          Agent.stop(pid)
        catch
          :exit, _ -> :ok
        end

      _ ->
        :ok
    end
  end

  def game_pages do
    Agent.get(__MODULE__, fn state ->
      state.requests
      |> Enum.filter(&String.contains?(&1, "/games?"))
      |> Enum.map(&page_from_url/1)
    end)
  end

  def get_with_retry(url, _headers \\ [], _retries \\ 0) do
    if Process.whereis(__MODULE__) do
      Agent.update(__MODULE__, fn state ->
        %{state | requests: state.requests ++ [url]}
      end)

      page = page_from_url(url) || "1"

      case Agent.get(__MODULE__, &Map.get(&1.pages, page)) do
        nil -> {:error, "unexpected url: #{url}"}
        {:raw, body} -> {:ok, body}
        payload -> {:ok, Jason.encode!(payload)}
      end
    else
      {:error, "http stub not started"}
    end
  end

  defp page_from_url(url) do
    url
    |> URI.parse()
    |> Map.get(:query)
    |> case do
      nil -> nil
      query -> URI.decode_query(query)["page"]
    end
  end
end

defmodule Wololo.PlayerGamesAPITest do
  use ExUnit.Case, async: false

  alias Wololo.PlayerGamesAPI
  alias Wololo.PlayerGamesAPITest.HTTPStub

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

    assert {:ok, %{countries: countries, ratings: ratings}} =
             PlayerGamesAPI.process_games(body, 42)

    assert countries["de"] == 66.7
    assert countries["us"] == 33.3
    assert length(ratings) == 3
    assert Enum.map(ratings, & &1.player_rating) == [1420, 1410, 1400]
  end

  test "process_games errors when there are no valid 1v1 games" do
    assert {:error, message} = PlayerGamesAPI.process_games(~s({"games":[]}), 42)
    assert message =~ "No 1v1 ranked games"
  end

  test "process_games returns an error instead of raising on invalid JSON" do
    assert {:error, message} = PlayerGamesAPI.process_games("{", 42)
    assert message =~ "invalid JSON"
  end

  test "10-game moving average starts once ten earlier games exist" do
    games = for rating <- 1012..1001//-1, do: game(42, 99, "de", rating)

    assert {:ok, %{ratings: ratings}} =
             PlayerGamesAPI.process_games(Jason.encode!(%{"games" => games}), 42)

    assert Enum.map(ratings, & &1.player_rating) == Enum.to_list(1001..1012)
    assert Enum.at(ratings, 9).moving_average_10g == nil
    assert Enum.at(ratings, 10).moving_average_10g == 1005.5
  end

  describe "get_players_games_statistics pagination" do
    setup do
      previous = Application.get_env(:wololo, :http_client)
      Application.put_env(:wololo, :http_client, HTTPStub)

      on_exit(fn ->
        HTTPStub.stop()

        if previous do
          Application.put_env(:wololo, :http_client, previous)
        else
          Application.delete_env(:wololo, :http_client)
        end
      end)

      :ok
    end

    test "does not fetch page 2 when next_page is null even if total is over 50" do
      {:ok, _} =
        HTTPStub.start(%{
          "1" => %{
            "games" => [game(42, 99, "de", 1400)],
            "total" => 87,
            "next_page" => nil
          }
        })

      assert {:ok, body} = PlayerGamesAPI.get_players_games_statistics(42, false)
      assert length(Jason.decode!(body)["games"]) == 1
      assert HTTPStub.game_pages() == ["1"]
    end

    test "a truncated games page is an error instead of a crash" do
      {:ok, _} = HTTPStub.start(%{"1" => {:raw, "{\"games\":"}})

      assert {:error, message} = PlayerGamesAPI.get_players_games_statistics(42, false)
      assert message =~ "invalid JSON"
    end

    test "merges a next page that omits the games list" do
      {:ok, _} =
        HTTPStub.start(%{
          "1" => %{
            "games" => [game(42, 99, "de", 1400)],
            "total" => 2,
            "next_page" => 2
          },
          "2" => %{"total" => 2}
        })

      assert {:ok, body} = PlayerGamesAPI.get_players_games_statistics(42, false)
      assert length(Jason.decode!(body)["games"]) == 1
    end

    test "win rates by length skip games that have no duration" do
      short =
        game(42, 99, "de", 1400)
        |> Map.put("duration", 500)

      long =
        game(42, 100, "us", 1410)
        |> Map.put("duration", 4000)
        |> put_in(["teams", Access.at(0), Access.at(0), "player", "result"], "loss")

      missing = Map.delete(game(42, 101, "fr", 1420), "duration")

      {:ok, _} =
        HTTPStub.start(%{
          "1" => %{"games" => [short, long, missing], "total" => 3, "next_page" => nil}
        })

      assert {:ok, rates} = PlayerGamesAPI.get_player_wr_by_game_length(42)
      assert rates._lt_600 == 100.0
      assert rates._gte3600 == 0.0
      assert rates._1500_to_1799 == 0
    end

    test "fetches and merges the page named by next_page" do
      {:ok, _} =
        HTTPStub.start(%{
          "1" => %{
            "games" => [game(42, 99, "de", 1400)],
            "total" => 51,
            "next_page" => 2
          },
          "2" => %{
            "games" => [game(42, 100, "us", 1410)],
            "total" => 51,
            "next_page" => nil
          }
        })

      assert {:ok, body} = PlayerGamesAPI.get_players_games_statistics(42, false)
      games = Jason.decode!(body)["games"]
      assert length(games) == 2
      assert HTTPStub.game_pages() == ["1", "2"]
    end

    test "keeps page 1 when the next page request fails" do
      {:ok, _} =
        HTTPStub.start(%{
          "1" => %{
            "games" => [game(42, 99, "de", 1400)],
            "total" => 51,
            "next_page" => 2
          }
        })

      assert {:ok, body} = PlayerGamesAPI.get_players_games_statistics(42, false)
      assert length(Jason.decode!(body)["games"]) == 1
    end
  end
end
