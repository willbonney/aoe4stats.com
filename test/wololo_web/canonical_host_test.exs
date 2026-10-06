defmodule WololoWeb.CanonicalHostTest do
  use ExUnit.Case, async: true

  alias WololoWeb.Plugs.CanonicalHost

  defp call(method, path, host) do
    method
    |> Plug.Test.conn(path)
    |> Map.put(:host, host)
    |> CanonicalHost.call([])
  end

  test "alias hosts redirect to the apex and keep the query string" do
    conn = call(:get, "/civs_by_map?league=gold", "wololo.fly.dev")
    assert conn.status == 301
    assert conn.halted
    assert Plug.Conn.get_resp_header(conn, "location") == [
             "https://aoe4stats.com/civs_by_map?league=gold"
           ]
  end

  test "HEAD is redirected and POST is not" do
    head = call(:head, "/meta", "www.aoe4stats.com")
    assert head.status == 301

    post = call(:post, "/meta", "www.aoe4stats.com")
    refute post.halted
    assert post.status == nil
  end

  test "trailing slashes redirect on the same host, and the root does not" do
    slashed = call(:get, "/leaderboard/?tab=top", "localhost")
    assert slashed.status == 301
    assert Plug.Conn.get_resp_header(slashed, "location") == ["/leaderboard?tab=top"]

    root = call(:get, "/", "www.aoe4.win")
    assert root.status == 301
    assert Plug.Conn.get_resp_header(root, "location") == ["https://aoe4stats.com/"]

    local_root = call(:get, "/", "localhost")
    refute local_root.halted
  end
end
