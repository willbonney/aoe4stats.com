defmodule WololoWeb.InsightsLive do
  use WololoWeb, :live_component
  require Logger
  alias Wololo.PlayerGamesAPI
  import WololoWeb.Components.Spinner

  defp default_prompt(player_name) do
    """
    The prompt provided to you is a json object that contains data regarding an Age of Empires IV player profile. The player plays games on the ladder and gains/loses rating depending on the outcome.

    Your answer should provide 5 insights about this data. The insights should not be superficial, they should involve deeper reasoning about the statistics in the prompt. For example, you could answer that the player has a significantly higher winrate on weekends than on weekdays. Or you could say that the player's winrate against opponents located in China is the lowest among all other countries.

    Remember that the `country` key in the `player` object is a two-letter country code. You can use this to determine the country of the player's opponents. This is not the same as the `civilization` key, which is the civilization the player chose to play with.

    The format of your answer should be in HTML for easy parsing. Do not wrap the answer with any non-HTML syntax like ```. Do not include <html>, <head>, or <body> tags.

    Structure your response as follows:
    - Start with a <div> container
    - Use <ul class="space-y-6 my-8"> for the list
    - Each insight should be an <li class="text-base leading-relaxed"> element
    - Use <strong> tags to emphasize key points and numbers
    - The content will be wrapped in prose classes, so use semantic HTML (p, strong, em) for styling

    Instead of using "the player" to refer to the player, use <strong>#{player_name}</strong> instead (already bolded).

    Make the insights engaging, specific, and backed by the data. Include actual numbers and percentages where relevant.
    """
  end

  def call(_, %{:player_name => player_name, :prompt => prompt}) do
    cache_key = "grok_#{:crypto.hash(:md5, prompt) |> Base.encode16()}"

    case Cachex.get(:wololo_cache, cache_key) do
      {:ok, nil} ->
        # Cache miss, make the API call
        result = make_grok_request(player_name, prompt)

        # Only cache successful responses (maps with content)
        case result do
          %{"content" => _} ->
            Cachex.put(:wololo_cache, cache_key, result, ttl: :timer.hours(24))

          _ ->
            Logger.warning("Not caching error response")
        end

        result

      {:ok, cached_result} ->
        # Cache hit, return the cached result
        cached_result

      {:error, _cache_error} ->
        # Error reading from cache, fall back to API call
        make_grok_request(player_name, prompt)
    end
  end

  defp make_grok_request(player_name, prompt) do
    request_body = %{
      "model" => "grok-4-fast-reasoning",
      "messages" => [
        %{"role" => "system", "content" => default_prompt(player_name)},
        %{"role" => "user", "content" => prompt || ""}
      ],
      "temperature" => 0.7
    }

    request_body
    |> Jason.encode!()
    |> request(nil)
    |> parse_response()
  end

  defp parse_response({:ok, body}) do
    case Jason.decode(body) do
      {:ok, decoded} ->
        messages =
          decoded
          |> Map.get("choices", [])
          |> Enum.reverse()

        case messages do
          [%{"message" => message} | _] ->
            message

          _ ->
            Logger.warning("No messages found in Grok response")
            "{}"
        end

      {:error, decode_error} ->
        Logger.error("Failed to decode Grok JSON response: #{inspect(decode_error)}")
        {:error, "Failed to decode response"}
    end
  end

  defp parse_response({:error, reason}) do
    Logger.error("Grok API request failed: #{inspect(reason)}")
    {:error, "Grok API request failed: #{inspect(reason)}"}
  end

  defp request(body, _opts) do
    api_key = Application.get_env(:wololo, :grok_api_key)
    endpoint = "https://api.x.ai/v1/chat/completions"

    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{api_key}"}
    ]

    Wololo.HTTPClient.post(endpoint, body, headers)
  end

  @impl true
  def mount(socket) do
    {:ok, socket |> assign(error: nil, insights: nil)}
  end

  @impl true
  def update(assigns, socket) do
    profile_id = assigns[:profile_id]
    player_name = assigns[:player_name]

    socket =
      socket
      |> assign(assigns)
      |> assign_async(:insights, fn -> fetch_insights(profile_id, player_name) end)

    {:ok, socket}
  end

  defp fetch_insights(profile_id, player_name) do
    case PlayerGamesAPI.get_players_games_statistics(profile_id, false) do
      {:ok, data} ->
        case call(nil, %{player_name: player_name, prompt: data}) do
          response when is_map(response) ->
            case Map.get(response, "content") do
              content when is_binary(content) ->
                {:ok, %{insights: content}}

              _ ->
                Logger.error("Invalid response format from Grok API")
                {:error, "Invalid response format from Grok"}
            end

          error ->
            Logger.error("Unexpected Grok response: #{inspect(error)}")
            {:error, "Unexpected response: #{inspect(error)}"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end
