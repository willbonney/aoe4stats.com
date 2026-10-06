defmodule Wololo.SearchPlayerAPITest.HTTPStub do
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
    Agent.get(__MODULE__, & &1.urls)
  end

  def get_with_retry(url, _headers \\ [], _retries \\ 0) do
    Agent.get_and_update(__MODULE__, fn state ->
      {state.fun.(url), %{state | urls: state.urls ++ [url]}}
    end)
  end
end

defmodule Wololo.SearchPlayerAPITest do
  use ExUnit.Case, async: false

  alias Wololo.SearchPlayerAPI
  alias Wololo.SearchPlayerAPITest.HTTPStub

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

  test "returns autocomplete players and encodes the query" do
    {:ok, _} =
      HTTPStub.start(fn _url ->
        {:ok, Jason.encode!(%{"players" => [%{"name" => "Beastyqt", "profile_id" => 1}]})}
      end)

    assert {:ok, %{"players" => [%{"name" => "Beastyqt"}]}} =
             SearchPlayerAPI.fetch_player("Beast y")

    assert hd(HTTPStub.urls()) =~ "query=Beast+y"
    assert hd(HTTPStub.urls()) =~ "leaderboard=rm_solo"
  end

  test "returns an error when the body is not JSON" do
    {:ok, _} = HTTPStub.start(fn _url -> {:ok, "{\"players\":"} end)

    assert {:error, message} = SearchPlayerAPI.fetch_player("Beast")
    assert message =~ "invalid JSON"
  end

  test "returns an error when the request fails" do
    {:ok, _} = HTTPStub.start(fn _url -> {:error, "timeout"} end)

    assert {:error, message} = SearchPlayerAPI.fetch_player("Beast")
    assert message =~ "timeout"
  end

  test "rejects a missing name" do
    assert {:error, message} = SearchPlayerAPI.fetch_player(nil)
    assert message =~ "invalid name"
  end
end
