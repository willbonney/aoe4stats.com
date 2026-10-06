defmodule WololoWeb.CivsByLeagueLiveTest.HTTPStub do
  def get_with_retry(url, _headers \\ [], _retries \\ 0) do
    league =
      url
      |> URI.parse()
      |> Map.get(:query)
      |> URI.decode_query()
      |> Map.get("rank_level")

    {:ok,
     Jason.encode!(%{
       "data" => [%{"civilization" => "english", "win_rate" => 50.0 + String.length(league) / 10}]
     })}
  end
end

defmodule WololoWeb.CivsByLeagueLiveTest do
  use WololoWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  setup do
    Enum.each(Wololo.CivsByLeagueAPI.league_order(), fn league ->
      Cachex.del(:wololo_cache, "civs_by_league_#{league}")
    end)

    Cachex.del(:wololo_cache, "civs_by_league_all")

    previous = Application.get_env(:wololo, :http_client)
    Application.put_env(:wololo, :http_client, WololoWeb.CivsByLeagueLiveTest.HTTPStub)

    on_exit(fn ->
      if previous do
        Application.put_env(:wololo, :http_client, previous)
      else
        Application.delete_env(:wololo, :http_client)
      end
    end)

    :ok
  end

  test "selecting every civilization updates the filter count", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/civs_by_league")
    html = if html =~ "Select All", do: html, else: render(view)

    assert html =~ "Civilizations (0/23)"
    refute html =~ "Failed to fetch"

    selected = view |> element("button", "Select All") |> render_click()
    assert selected =~ "Civilizations (23/23)"

    cleared = view |> element("button", "Clear All") |> render_click()
    assert cleared =~ "Civilizations (0/23)"
  end
end
