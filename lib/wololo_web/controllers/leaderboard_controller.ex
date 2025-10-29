defmodule WololoWeb.LeaderboardController do
  use WololoWeb, :controller
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

  def search(conn, %{"name" => name}) do
    case LeaderboardDumpCron.get_cached_data() do
      {:ok, data} ->
        name_lower = String.downcase(name)

        results =
          data
          |> Enum.filter(fn entry ->
            String.downcase(entry.name) |> String.contains?(name_lower)
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
    end
  end
end
