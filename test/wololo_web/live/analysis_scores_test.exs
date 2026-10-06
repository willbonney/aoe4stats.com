defmodule Wololo.AnalysisScoresTest.HTTPStub do
  def start(responses) do
    Agent.start_link(fn -> responses end, name: __MODULE__)
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

  def get_with_retry(url, _headers \\ [], _retries \\ 0) do
    state = Agent.get(__MODULE__, & &1)

    cond do
      String.contains?(url, "/games?") -> state.games
      String.contains?(url, "/players/") -> state.player
      true -> {:error, "unexpected url: #{url}"}
    end
  end
end

defmodule Wololo.AnalysisScoresTest do
  use ExUnit.Case, async: false

  alias Wololo.AnalysisScoresTest.HTTPStub
  alias WololoWeb.AnalysisLive

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

  defp history(entries) do
    entries
    |> Enum.with_index(1)
    |> Map.new(fn {entry, index} ->
      day = index |> Integer.to_string() |> String.pad_leading(2, "0")
      {"2026-01-#{day}", entry}
    end)
  end

  defp player_body(entries, civs) do
    Jason.encode!(%{
      "modes" => %{
        "rm_solo" => %{
          "rating_history" => history(entries),
          "civilizations" => civs
        }
      }
    })
  end

  defp game(result) do
    %{
      "teams" => [
        [%{"player" => %{"profile_id" => 42, "rating" => 1500, "result" => result}}],
        [%{"player" => %{"profile_id" => 99, "rating" => 1700, "result" => "loss"}}]
      ]
    }
  end

  test "scores a steady climber who wins against higher-rated opponents" do
    entries = for _ <- 1..12, do: %{"rating" => 1500, "streak" => 1}
    games = for _ <- 1..20, do: game("win")

    {:ok, _} =
      HTTPStub.start(%{
        player: {:ok, player_body(entries, [%{"games_count" => 20, "win_rate" => 60.0}])},
        games: {:ok, Jason.encode!(%{"games" => games, "next_page" => nil})}
      })

    scores = AnalysisLive.fetch_analysis("42")
    assert scores.peak_proximity == 100.0
    assert scores.recovery == 100.0
    assert scores.momentum == 0.0
    assert scores.anti_tilt == 75.0
    assert scores.pressure_performance == 100.0
    assert scores.rating_efficiency == 50.0
    assert scores.versatility == 0.0
    assert scores.underdog_success == 100.0
  end

  test "missing streak and rating values do not crash the scores" do
    entries =
      for i <- 1..12 do
        if rem(i, 4) == 0 do
          %{"rating" => nil, "streak" => nil}
        else
          %{"rating" => 1400 + i, "streak" => 1}
        end
      end

    {:ok, _} =
      HTTPStub.start(%{
        player: {:ok, player_body(entries, [%{"games_count" => nil, "win_rate" => nil}])},
        games: {:ok, Jason.encode!(%{"games" => nil})}
      })

    assert %{} = scores = AnalysisLive.fetch_analysis("42")
    assert is_number(scores.peak_proximity) or is_nil(scores.peak_proximity)
    assert scores.versatility == nil
    assert scores.underdog_success == nil
  end

  test "short histories stay unscored" do
    {:ok, _} =
      HTTPStub.start(%{
        player: {:ok, player_body([%{"rating" => 1000, "streak" => 1}], [])},
        games: {:ok, Jason.encode!(%{"games" => [game("win")], "next_page" => nil})}
      })

    scores = AnalysisLive.fetch_analysis("42")
    assert scores.peak_proximity == nil
    assert scores.recovery == nil
    assert scores.momentum == nil
    assert scores.anti_tilt == nil
    assert scores.pressure_performance == nil
    assert scores.rating_efficiency == nil
    assert scores.underdog_success == nil
  end

  test "a failed player fetch is returned as an error" do
    {:ok, _} = HTTPStub.start(%{player: {:error, "boom"}, games: {:error, "unused"}})

    assert {:error, reason} = AnalysisLive.fetch_analysis("42")
    assert reason =~ "boom"
  end
end
