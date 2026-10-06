defmodule Wololo.SearchPlayerAPI do
  require Logger

  @base_url Application.compile_env(:wololo, :api_base_url)

  def fetch_player(name) when is_binary(name) do
    encoded_name = URI.encode_www_form(name)
    endpoint = "#{@base_url}/players/autocomplete?leaderboard=rm_solo&query=#{encoded_name}"

    case http_client().get_with_retry(endpoint) do
      {:ok, body} ->
        case Jason.decode(body) do
          {:ok, data} -> {:ok, data}
          {:error, _} -> {:error, "search_player_api fetch_player failed: invalid JSON"}
        end

      {:error, reason} ->
        {:error, "search_player_api fetch_player failed: #{reason}"}
    end
  end

  def fetch_player(_name) do
    {:error, "search_player_api fetch_player failed: invalid name"}
  end

  defp http_client do
    Application.get_env(:wololo, :http_client, Wololo.HTTPClient)
  end
end
