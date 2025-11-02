defmodule WololoWeb.LeaderboardLive do
  use WololoWeb, :live_view
  require Logger
  alias Wololo.CountryPopulations

  def mount(_params, _session, socket) do
    if connected?(socket) do
      send(self(), :load_leaderboard)
    end

    {:ok,
     socket
     |> assign(
       loading: true,
       error: nil,
       active_tab: "conqueror",
       conqueror_data: %{distribution: %{}, total: 0},
       conqueror3_data: %{distribution: %{}, total: 0},
       top100_data: %{distribution: %{}, total: 0},
       per_capita_data: %{distribution: %{}, total: 0},
       avg_rank_data: %{ranked: [], total: 0},
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
           conqueror_data: data.conqueror_data,
           conqueror3_data: data.conqueror3_data,
           top100_data: data.top100_data,
           per_capita_data: data.per_capita_data,
           avg_rank_data: data.avg_rank_data,
           last_updated: data.last_updated
         )
         |> push_event("update-leaderboard-countries", %{
           tab: "conqueror",
           byCountry: data.conqueror_data.distribution
         })}

      {:error, reason} ->
        Logger.error("Failed to load leaderboard: #{inspect(reason)}")

        {:noreply,
         socket
         |> assign(loading: false, error: reason)}
    end
  end

  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    # avg_rank and per_capita don't use the chart, so don't send event
    if tab in ["per_capita", "avg_rank"] do
      {:noreply, socket |> assign(active_tab: tab)}
    else
      data =
        case tab do
          "conqueror" -> socket.assigns.conqueror_data
          "conqueror3" -> socket.assigns.conqueror3_data
          "top100" -> socket.assigns.top100_data
          _ -> socket.assigns.conqueror_data
        end

      {:noreply,
       socket
       |> assign(active_tab: tab)
       |> push_event("update-leaderboard-countries", %{
         tab: tab,
         byCountry: data.distribution
       })}
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

        # Pre-filter players into tiers (single pass through the data)
        # CSV is already sorted by rank, so we just need to filter by rating
        {conqueror_players, conqueror3_players} =
          Enum.reduce(players, {[], []}, fn player, {conq, conq3} ->
            case player.rating do
              rating when is_integer(rating) and rating >= 2000 ->
                # 2000+ qualifies for both tiers
                {[player | conq], [player | conq3]}

              rating when is_integer(rating) and rating > 1400 ->
                # 1400+ qualifies only for conqueror
                {[player | conq], conq3}

              _ ->
                {conq, conq3}
            end
          end)

        # Top 100 players (already sorted by rank in CSV)
        top100_players = Enum.take(players, 100)

        # Calculate distributions from pre-filtered lists
        conqueror_data = calculate_country_distribution(conqueror_players)
        conqueror3_data = calculate_country_distribution(conqueror3_players)
        top100_data = calculate_country_distribution(top100_players)
        per_capita_data = calculate_per_capita_distribution(conqueror_players)
        avg_rank_data = calculate_avg_rank_by_country(players)

        {:ok,
         %{
           conqueror_data: conqueror_data,
           conqueror3_data: conqueror3_data,
           top100_data: top100_data,
           per_capita_data: per_capita_data,
           avg_rank_data: avg_rank_data,
           last_updated: last_updated
         }}

      {:error, :not_found} ->
        {:error, "Leaderboard data not yet available. First sync in progress."}

      {:error, reason} ->
        {:error, "Failed to retrieve leaderboard data: #{inspect(reason)}"}
    end
  end

  defp calculate_country_distribution(players) do
    country_counts =
      Enum.reduce(players, %{}, fn player, acc ->
        country = player.country || "unknown"
        Map.update(acc, country, 1, &(&1 + 1))
      end)

    total = length(players)

    if total == 0 do
      %{distribution: %{}, total: 0}
    else
      distribution =
        Enum.map(country_counts, fn {country, count} ->
          {country, Float.round(count / total * 100, 2)}
        end)
        |> Enum.into(%{})

      %{distribution: distribution, total: total}
    end
  end

  defp calculate_per_capita_distribution(players) do
    country_counts =
      Enum.reduce(players, %{}, fn player, acc ->
        country = player.country || "unknown"
        Map.update(acc, country, 1, &(&1 + 1))
      end)

    # This is conquerors per million people
    per_capita_list =
      country_counts
      |> Enum.filter(fn {country, _count} ->
        country != "unknown" && CountryPopulations.has_data?(country)
      end)
      |> Enum.map(fn {country, count} ->
        population = CountryPopulations.get_population(country)
        per_capita = count / population

        %{
          country: country,
          per_capita: Float.round(per_capita, 2),
          count: count
        }
      end)
      |> Enum.sort_by(& &1.per_capita, :desc)

    # Also keep map format for chart
    per_capita_map =
      per_capita_list
      |> Enum.map(fn item -> {item.country, item.per_capita} end)
      |> Enum.into(%{})

    total = length(per_capita_list)

    %{distribution: per_capita_map, ranked: per_capita_list, total: total}
  end

  defp calculate_avg_rank_by_country(players) do
    # Group players by country and calculate average rank
    country_ranks =
      players
      |> Enum.filter(fn player -> player.country && player.country != "unknown" end)
      |> Enum.group_by(fn player -> player.country end)
      |> Enum.map(fn {country, country_players} ->
        ranks = Enum.map(country_players, fn p -> p.rank end)
        avg_rank = Enum.sum(ranks) / length(ranks)

        %{
          country: country,
          avg_rank: Float.round(avg_rank, 1),
          player_count: length(country_players),
          best_rank: Enum.min(ranks)
        }
      end)
      |> Enum.sort_by(& &1.avg_rank)

    %{ranked: country_ranks, total: length(country_ranks)}
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

  defp get_country_name("unknown"), do: "Unknown"

  defp get_country_name(country_code) when is_binary(country_code) do
    country_code = String.upcase(country_code)

    case Cldr.Territory.from_territory_code(country_code, Wololo.Cldr) do
      {:ok, name} -> name
      _ -> country_code
    end
  end

  defp get_country_name(_), do: "Unknown"
end
