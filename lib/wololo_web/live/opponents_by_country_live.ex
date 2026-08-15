defmodule WololoWeb.OpponentsByCountryLive do
  use WololoWeb, :live_component
  alias Wololo.PlayerGamesAPI
  import WololoWeb.Components.Spinner

  def mount(socket) do
    {:ok, socket |> assign(profile_id: nil, countries: [], loading: true, error: nil)}
  end

  def update(assigns, socket) do
    WololoWeb.SentryContext.set_player_context(assigns[:profile_id])
    assign(socket, loading: true)

    case PlayerGamesAPI.get_players_games_statistics(assigns[:profile_id]) do
      {:ok, data} ->
        {
          :ok,
          socket
          |> assign(countries: data[:countries], loading: false, error: nil)
          |> push_event("update-opponents-by-country", %{byCountry: data[:countries]})
        }

      {:error, reason} ->
        {
          :ok,
          socket
          |> assign(countries: [], loading: false, error: reason)
        }
    end
  end

  defp sorted_countries(countries) when is_map(countries) do
    countries
    |> Enum.reject(fn {country, _} -> is_nil(country) or country in ["", "unknown"] end)
    |> Enum.sort_by(fn {_country, value} -> -value end)
  end

  defp sorted_countries(_), do: []

  defp country_name(country_code) when is_binary(country_code) do
    country_code = String.upcase(country_code)

    case Cldr.Territory.from_territory_code(country_code, Wololo.Cldr) do
      {:ok, name} -> name
      _ -> country_code
    end
  end

  defp country_name(_), do: "Unknown"
end
