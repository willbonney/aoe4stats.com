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

defmodule Wololo.PlayerStatsAPITest.HTTPStub do
  def start(responses) do
    Agent.start_link(fn -> %{responses: responses, urls: []} end, name: __MODULE__)
  end

  def stop do
    if pid = Process.whereis(__MODULE__), do: Agent.stop(pid)
  end

  def urls do
    Agent.get(__MODULE__, & &1.urls)
  end

  def get_with_retry(url, _headers \\ [], _retries \\ 0) do
    Agent.get_and_update(__MODULE__, fn state ->
      [body | rest] = state.responses
      {{:ok, body}, %{state | responses: rest, urls: state.urls ++ [url]}}
    end)
  end
end

defmodule Wololo.PlayerStatsAPIFetchTest do
  use ExUnit.Case, async: false

  alias Wololo.PlayerStatsAPI
  alias Wololo.PlayerStatsAPITest.HTTPStub

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

  test "summary request skips full history and does not raise on a short body" do
    {:ok, _} =
      HTTPStub.start(["{\"name\":\"Riv", Jason.encode!(%{"name" => "Riv", "country" => "us"})])

    assert {:ok, %{"name" => "Riv", "country" => "us"}} =
             PlayerStatsAPI.fetch_player_summary("6302755")

    assert HTTPStub.urls() == [
             "https://aoe4world.com/api/v0/players/6302755",
             "https://aoe4world.com/api/v0/players/6302755"
           ]
  end

  test "a body that stays truncated becomes an error" do
    {:ok, _} = HTTPStub.start(["{\"name\":", "{\"name\":"])

    assert {:error, "fetch_player_data failed: invalid JSON"} =
             PlayerStatsAPI.fetch_player_data("6302755")

    assert Enum.all?(HTTPStub.urls(), &String.ends_with?(&1, "?full_history=true"))
  end

  test "with_stats still reads the full history payload" do
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
            "previous_seasons" => [%{"season" => 9, "rank" => 60}],
            "rating_history" => %{"1" => %{"rating" => 1500}}
          }
        }
      })

    {:ok, _} = HTTPStub.start([body])

    assert {:ok, stats} = PlayerStatsAPI.fetch_player_data("6302755", true)
    assert stats.max_rating == 1600
    assert HTTPStub.urls() == ["https://aoe4world.com/api/v0/players/6302755?full_history=true"]
  end
end
