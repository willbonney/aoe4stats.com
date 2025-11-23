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

    Structure your response EXACTLY as follows:

    <div class="space-y-6 my-8">
      <div class="bg-white dark:bg-zinc-800 rounded-lg shadow-md hover:shadow-lg transition-shadow p-8 border border-stone-200 dark:border-zinc-700">
        <div class="flex items-center gap-8">
          <div class="flex-shrink-0 flex items-center justify-center">
            <span class="text-7xl font-bold text-stone-300 dark:text-zinc-700">1</span>
          </div>
          <div class="flex-1">
            <p class="text-base leading-relaxed text-stone-900 dark:text-zinc-100">
              Your insight text here with <strong>emphasized numbers</strong> and key points.
            </p>
          </div>
        </div>
      </div>
      <!-- Repeat for insights 2-5 with numbers 2, 3, 4, 5 -->
    </div>

    Each card should have:
    - A large number (1-5) on the left side using text-7xl
    - The number should be in light gray (text-stone-300 dark:text-zinc-700)
    - The insight text with <strong> tags for emphasis on numbers and key stats
    - Use the exact class structure shown above, including items-center for vertical centering

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
    WololoWeb.SentryContext.set_player_context(profile_id)

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
