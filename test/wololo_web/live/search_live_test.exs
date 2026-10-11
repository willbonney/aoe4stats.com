defmodule WololoWeb.SearchLiveTest.HTTPStub do
  def get_with_retry(url, _headers \\ [], _retries \\ 0) do
    cond do
      String.contains?(url, "query=bad") ->
        {:ok, "{"}

      true ->
        {:ok,
         Jason.encode!(%{
           "players" => [
             %{"profile_id" => 9, "name" => "Beastyqt", "rank" => 1, "rating" => 2200, "win_rate" => 61}
           ]
         })}
    end
  end
end

defmodule WololoWeb.SearchLiveTest do
  use WololoWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  setup do
    previous = Application.get_env(:wololo, :http_client)
    Application.put_env(:wololo, :http_client, WololoWeb.SearchLiveTest.HTTPStub)

    on_exit(fn ->
      if previous do
        Application.put_env(:wololo, :http_client, previous)
      else
        Application.delete_env(:wololo, :http_client)
      end
    end)

    :ok
  end

  test "footer player stats opens search instead of the empty player page", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/")
    refute html =~ "Search solo ladder"
    refute html =~ ~s(href="/player")

    html = view |> element("footer button", "Player stats") |> render_click()
    assert html =~ "Search solo ladder"
  end

  test "search shows a player and survives a bad response", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")
    render_click(view, "show_search")
    assert render(view) =~ "Search solo ladder"

    view |> element("input[role=combobox]") |> render_keyup(%{"value" => "Beast"})
    assert render(view) =~ "Beastyqt"

    view |> element("input[role=combobox]") |> render_keyup(%{"value" => "bad"})
    html = render(view)
    assert html =~ "No Results"
    refute html =~ "Beastyqt"
  end
end
