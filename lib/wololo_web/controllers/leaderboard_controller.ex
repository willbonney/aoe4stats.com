defmodule WololoWeb.LeaderboardController do
  use WololoWeb, :controller
  require Logger
  alias Wololo.LeaderboardDumpCron

  def index(conn, _params) do
    case LeaderboardDumpCron.get_cached_data() do
      {:ok, data} ->
        last_updated =
          case LeaderboardDumpCron.last_updated() do
            {:ok, timestamp} -> DateTime.to_iso8601(timestamp)
            _ -> nil
          end

        json(conn, %{
          data: data,
          count: length(data),
          last_updated: last_updated
        })

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Leaderboard data not yet available. First sync in progress."})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to retrieve leaderboard data: #{inspect(reason)}"})
    end
  end

  def show(conn, %{"profile_id" => profile_id}) do
    case LeaderboardDumpCron.get_cached_data() do
      {:ok, data} ->
        case Enum.find(data, fn entry -> entry.profile_id == profile_id end) do
          nil ->
            conn
            |> put_status(:not_found)
            |> json(%{error: "Player not found in leaderboard"})

          player ->
            json(conn, player)
        end

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Leaderboard data not yet available"})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to retrieve leaderboard data: #{inspect(reason)}"})
    end
  end

  def search(conn, %{"name" => name}) when is_binary(name) and name != "" do
    case LeaderboardDumpCron.get_cached_data() do
      {:ok, data} when is_list(data) ->
        name_lower = String.downcase(name)

        results =
          data
          |> Enum.filter(fn entry ->
            entry_name = entry_name(entry)
            entry_name != "" and String.contains?(String.downcase(entry_name), name_lower)
          end)
          |> Enum.take(20)

        json(conn, %{
          results: results,
          count: length(results)
        })

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Leaderboard data not yet available"})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to retrieve leaderboard data: #{inspect(reason)}"})

      _ ->
        json(conn, %{results: [], count: 0})
    end
  end

  def search(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing name"})
  end

  defp entry_name(%{name: name}) when is_binary(name), do: name
  defp entry_name(%{"name" => name}) when is_binary(name), do: name
  defp entry_name(_), do: ""

  def refresh(conn, _params) do
    # Run refresh on THIS machine in a Task
    Task.start(fn -> run_refresh() end)

    json(conn, %{status: "refresh started"})
  end

  defp run_refresh do
    refresh =
      Application.get_env(:wololo, :leaderboard_refresh, &LeaderboardDumpCron.fetch_and_cache/0)

    if is_function(refresh, 0), do: refresh.(), else: LeaderboardDumpCron.fetch_and_cache()
  end
end
