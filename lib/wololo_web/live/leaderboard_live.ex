defmodule WololoWeb.LeaderboardLive do
  use WololoWeb, :live_view
  require Logger

  def mount(_params, _session, socket) do
    if connected?(socket) do
      send(self(), :load_leaderboard)
    end

    {:ok,
     socket
     |> assign(
       loading: true,
       error: nil,
       country_distribution: %{},
       total_conquerors: 0,
       last_updated: nil
     )}
  end

  def handle_info(:load_leaderboard, socket) do
    case fetch_and_process_leaderboard() do
      {:ok, data} ->
        {:noreply,
         socket
         |> assign(
           loading: false,
           country_distribution: data.country_distribution,
           total_conquerors: data.total_conquerors,
           last_updated: data.last_updated
         )
         |> push_event("update-leaderboard-countries", %{
           byCountry: data.country_distribution
         })}

      {:error, reason} ->
        Logger.error("Failed to load leaderboard: #{inspect(reason)}")

        {:noreply,
         socket
         |> assign(loading: false, error: reason)}
    end
  end

  defp fetch_and_process_leaderboard do
    # Directly access the cached data instead of making HTTP call
    alias Wololo.LeaderboardDumpCron

    case LeaderboardDumpCron.get_cached_data() do
      {:ok, players} when is_list(players) ->
        # Get last updated timestamp
        last_updated =
          case LeaderboardDumpCron.last_updated() do
            {:ok, timestamp} -> timestamp
            _ -> nil
          end

        # Filter for Conqueror players (rating > 1400)
        conquerors =
          Enum.filter(players, fn player ->
            case player.rating do
              rating when is_integer(rating) -> rating > 1400
              _ -> false
            end
          end)

        # Calculate country distribution
        country_counts =
          Enum.reduce(conquerors, %{}, fn player, acc ->
            country = player.country || "unknown"
            Map.update(acc, country, 1, &(&1 + 1))
          end)

        total = length(conquerors)

        if total == 0 do
          {:error, "No Conqueror players found in the leaderboard"}
        else
          # Convert to percentages
          country_distribution =
            Enum.map(country_counts, fn {country, count} ->
              {country, Float.round(count / total * 100, 2)}
            end)
            |> Enum.into(%{})

          {:ok,
           %{
             country_distribution: country_distribution,
             total_conquerors: total,
             last_updated: last_updated
           }}
        end

      {:error, :not_found} ->
        {:error, "Leaderboard data not yet available. First sync in progress."}

      {:error, reason} ->
        {:error, "Failed to retrieve leaderboard data: #{inspect(reason)}"}
    end
  end

  defp format_timestamp(%DateTime{} = dt) do
    Calendar.strftime(dt, "%B %d, %Y at %I:%M %p UTC")
  end

  defp format_timestamp(timestamp) when is_binary(timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, dt, _offset} ->
        Calendar.strftime(dt, "%B %d, %Y at %I:%M %p UTC")

      _ ->
        timestamp
    end
  end

  defp format_timestamp(_), do: "Unknown"

  defp format_number(number) when is_integer(number) do
    case Wololo.Cldr.Number.to_string(number) do
      {:ok, formatted} -> formatted
      _ -> Integer.to_string(number)
    end
  end

  defp format_number(number), do: to_string(number)
end
