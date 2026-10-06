defmodule Wololo.HTTPClientTest.Plug do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, opts) do
    agent = Keyword.fetch!(opts, :agent)
    {:ok, body, conn} = read_body(conn)
    ua = conn |> get_req_header("user-agent") |> List.first()

    hits =
      Agent.get_and_update(agent, fn state ->
        hits = state.hits + 1
        {hits, %{state | hits: hits, last_ua: ua, last_body: body}}
      end)

    case conn.request_path do
      "/ok" ->
        send_resp(conn, 200, "hello")

      "/status" ->
        send_resp(conn, 503, "nope")

      "/post" ->
        send_resp(conn, 200, body)

      "/flaky" ->
        if hits == 1, do: send_resp(conn, 503, "nope"), else: send_resp(conn, 200, "recovered")
    end
  end
end

defmodule Wololo.HTTPClientTest do
  use ExUnit.Case, async: false

  alias Wololo.HTTPClient

  setup_all do
    {:ok, agent} = Agent.start_link(fn -> %{hits: 0, last_ua: nil, last_body: nil} end)

    {:ok, server} =
      Bandit.start_link(
        plug: {Wololo.HTTPClientTest.Plug, agent: agent},
        port: 0,
        ip: {127, 0, 0, 1},
        startup_log: false
      )

    {:ok, {_ip, port}} = ThousandIsland.listener_info(server)

    on_exit(fn ->
      ref = Process.monitor(server)
      Process.exit(server, :shutdown)

      receive do
        {:DOWN, ^ref, _, _, _} -> :ok
      after
        2_000 -> :ok
      end
    end)

    {:ok, agent: agent, base: "http://127.0.0.1:#{port}"}
  end

  setup %{agent: agent} do
    Agent.update(agent, fn state -> %{state | hits: 0, last_ua: nil, last_body: nil} end)
    :ok
  end

  test "GET returns the body and sends the app user agent", %{agent: agent, base: base} do
    assert {:ok, "hello"} = HTTPClient.get(base <> "/ok")
    assert Agent.get(agent, & &1.last_ua) == "aoe4stats/1.0"
    assert Agent.get(agent, & &1.hits) == 1
  end

  test "keeps a caller-supplied user agent", %{agent: agent, base: base} do
    assert {:ok, "hello"} = HTTPClient.get(base <> "/ok", [{"User-Agent", "custom"}])
    assert Agent.get(agent, & &1.last_ua) == "custom"
  end

  test "turns a non-200 into an error without retrying when retries are zero", %{
    agent: agent,
    base: base
  } do
    assert {:error, message} = HTTPClient.get_with_retry(base <> "/status", [], 0)
    assert message =~ "503"
    assert Agent.get(agent, & &1.hits) == 1
  end

  test "retries a failed GET", %{agent: agent, base: base} do
    assert {:ok, "recovered"} = HTTPClient.get_with_retry(base <> "/flaky", [], 1)
    assert Agent.get(agent, & &1.hits) == 2
  end

  test "POST sends the body", %{agent: agent, base: base} do
    assert {:ok, "payload"} = HTTPClient.post(base <> "/post", "payload")
    assert Agent.get(agent, & &1.last_body) == "payload"
  end
end
