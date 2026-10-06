defmodule Wololo.CivsByLeagueAPITest.HTTPStub do
  def start(fun) do
    Agent.start_link(fn -> %{fun: fun, urls: []} end, name: __MODULE__)
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

  def urls do
    Agent.get(__MODULE__, &Enum.reverse(&1.urls))
  end

  def get_with_retry(url, _headers \\ [], _retries \\ 0) do
    Agent.get_and_update(__MODULE__, fn state ->
      {state.fun.(url), %{state | urls: [url | state.urls]}}
    end)
  end
end

defmodule Wololo.CivsByLeagueAPITest do
  use ExUnit.Case, async: false

  alias Wololo.CivsByLeagueAPI
  alias Wololo.CivsByLeagueAPITest.HTTPStub

  setup do
    Enum.each(CivsByLeagueAPI.league_order(), fn league ->
      Cachex.del(:wololo_cache, "civs_by_league_#{league}")
    end)

    Cachex.del(:wololo_cache, "civs_by_league_all")
    Cachex.del(:wololo_cache, "civs_by_league_broken")

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

  test "fetches every league, rounds win rates, and caches the result" do
    {:ok, _} =
      HTTPStub.start(fn url ->
        if String.contains?(url, "rank_level=broken") do
          {:ok, "not-json"}
        else
          {:ok,
           Jason.encode!(%{
             "data" => [
               %{"civilization" => "english", "win_rate" => 51.239},
               %{"civilization" => 12, "win_rate" => 10},
               %{"win_rate" => 40}
             ]
           })}
        end
      end)

    assert {:ok, data} = CivsByLeagueAPI.fetch_all_leagues()
    assert Map.keys(data) |> Enum.sort() == Enum.sort(CivsByLeagueAPI.league_order())
    assert data["conqueror"] == %{"english" => 51.24}
    assert length(HTTPStub.urls()) == 6

    assert {:ok, ^data} = CivsByLeagueAPI.fetch_all_leagues()
    assert length(HTTPStub.urls()) == 6

    assert {:error, message} = CivsByLeagueAPI.fetch_league_data("broken")
    assert message =~ "JSON"
  end
end
