defmodule Wololo.CivsMetaAPITest.HTTPStub do
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

defmodule Wololo.CivsMetaAPITest do
  use ExUnit.Case, async: false

  alias Wololo.CivsMetaAPI
  alias Wololo.CivsMetaAPITest.HTTPStub

  setup do
    Cachex.del(:wololo_cache, "civs_meta_all")
    Cachex.del(:wololo_cache, "civs_meta_≥platinum")

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

  test "fetches meta, drops unknown rows, and encodes the league" do
    {:ok, _} =
      HTTPStub.start(fn _url ->
        {:ok,
         Jason.encode!(%{
           "data" => [
             %{
               "civilization" => "english",
               "win_rate" => 47.126,
               "pick_rate" => 12.6,
               "games_count" => 20
             },
             %{"civilization" => "not_a_civ", "win_rate" => 80, "pick_rate" => 80},
             %{"civilization" => "french", "win_rate" => "high", "pick_rate" => 10}
           ]
         })}
      end)

    assert {:ok, raw} = CivsMetaAPI.fetch_meta("≥platinum")
    assert [point] = CivsMetaAPI.transform_data(raw)
    assert point.label == "English"
    assert point.win_rate == 47.13

    [url] = HTTPStub.urls()
    assert URI.decode_query(URI.parse(url).query)["rank_level"] == "≥platinum"

    assert {:ok, ^raw} = CivsMetaAPI.fetch_meta("≥platinum")
    assert length(HTTPStub.urls()) == 1
  end

  test "returns an error for invalid JSON" do
    {:ok, _} = HTTPStub.start(fn _url -> {:ok, "{"} end)
    assert {:error, "Invalid JSON response"} = CivsMetaAPI.fetch_meta()
  end
end
