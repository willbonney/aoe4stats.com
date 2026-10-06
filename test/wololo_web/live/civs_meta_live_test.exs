defmodule WololoWeb.CivsMetaLiveTest.HTTPStub do
  def start do
    Agent.start_link(fn -> [] end, name: __MODULE__)
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
    Agent.get(__MODULE__, &Enum.reverse/1)
  end

  def get_with_retry(url, _headers \\ [], _retries \\ 0) do
    if pid = Process.whereis(__MODULE__), do: Agent.update(pid, &[url | &1])

    {:ok,
     Jason.encode!(%{
       "data" => [
         %{
           "civilization" => "french",
           "win_rate" => 55.5,
           "pick_rate" => 9.25,
           "games_count" => 100
         }
       ]
     })}
  end
end

defmodule WololoWeb.CivsMetaLiveTest do
  use WololoWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  alias WololoWeb.CivsMetaLiveTest.HTTPStub

  setup do
    Cachex.del(:wololo_cache, "civs_meta_all")
    Cachex.del(:wololo_cache, "civs_meta_gold")

    previous = Application.get_env(:wololo, :http_client)
    Application.put_env(:wololo, :http_client, HTTPStub)
    HTTPStub.start()

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

  test "renders meta points and refetches when the league changes", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/meta")
    html = if html =~ "French", do: html, else: render(view)

    assert html =~ "French"
    assert html =~ "55.5"
    refute html =~ "Failed to fetch"

    view |> element("form") |> render_change(%{"league" => "gold"})
    assert render(view) =~ "French"

    assert Enum.any?(HTTPStub.urls(), fn url ->
             URI.decode_query(URI.parse(url).query || "")["rank_level"] == "gold"
           end)
  end
end
