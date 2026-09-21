defmodule WololoWeb.Plugs.CanonicalHost do
  @moduledoc """
  301s alias hosts to aoe4stats.com and strips trailing slashes so Google sees one URL per page.
  """

  import Plug.Conn

  @canonical "aoe4stats.com"

  @alias_hosts MapSet.new([
                 "www.aoe4stats.com",
                 "aoe4.win",
                 "www.aoe4.win",
                 "wololo.fly.dev"
               ])

  def init(opts), do: opts

  def call(%{method: method} = conn, _opts) when method in ["GET", "HEAD"] do
    cond do
      alias_host?(conn.host) ->
        redirect(conn, canonical_url(conn))

      trailing_slash?(conn.request_path) ->
        redirect(conn, path_without_slash(conn))

      true ->
        conn
    end
  end

  def call(conn, _opts), do: conn

  defp alias_host?(host), do: MapSet.member?(@alias_hosts, host)

  defp trailing_slash?("/"), do: false
  defp trailing_slash?(path), do: String.ends_with?(path, "/")

  defp canonical_url(conn) do
    "https://#{@canonical}#{strip_slash(conn.request_path)}#{query_suffix(conn)}"
  end

  defp path_without_slash(conn) do
    strip_slash(conn.request_path) <> query_suffix(conn)
  end

  defp strip_slash("/"), do: "/"
  defp strip_slash(path), do: String.trim_trailing(path, "/")

  defp query_suffix(%{query_string: ""}), do: ""
  defp query_suffix(%{query_string: qs}), do: "?" <> qs

  defp redirect(conn, location) do
    conn
    |> put_resp_header("location", location)
    |> send_resp(301, "")
    |> halt()
  end
end
