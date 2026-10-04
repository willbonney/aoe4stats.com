defmodule WololoWeb.PlayerLive do
  use WololoWeb, :live_view
  alias WololoWeb.OpponentsByCountryLive
  alias WololoWeb.InsightsLive
  alias WololoWeb.RatingLive
  alias WololoWeb.RankLive
  alias WololoWeb.GameLengthLive
  alias WololoWeb.AnalysisLive
  alias Wololo.PlayerStatsAPI

  @initial_assigns [
    active: nil,
    profile_id: nil,
    name: nil,
    avatar: nil,
    url: nil,
    rank: nil,
    wr: nil,
    error: nil,
    country_code: nil
  ]

  @impl true
  def mount(%{"profile_id" => profile_id} = _params, _session, socket)
      when not is_nil(profile_id) do
    send(self(), {:load_player_data, %{"id" => profile_id}})

    if connected?(socket) do
      :ok = Phoenix.PubSub.subscribe(Wololo.PubSub, "flash")
    end

    {:ok,
     socket
     |> assign(
       @initial_assigns ++
         [profile_id: profile_id, current_url: url(socket, ~p"/player/#{profile_id}/rating")]
     )
     |> hydrate_from_leaderboard(profile_id)}
  end

  def mount(_params, _session, socket) do
    {:ok,
     assign(
       socket,
       @initial_assigns ++ [current_url: url(socket, ~p"/player")]
     )}
  end

  @impl true
  def handle_event("select-player", params, socket) do
    send(self(), {:load_player_data, params})

    {:noreply,
     push_patch(socket,
       to: ~p"/player/#{params["id"]}/rating",
       replace: true
     )}
  end

  @impl true
  def handle_event(event, _params, socket) do
    case event do
      "copy_success" ->
        {:noreply, put_flash(socket, :info, "Copied player link to clipboard!")}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:load_player_data, %{"id" => profile_id}}, socket) do
    WololoWeb.SentryContext.set_player_context(profile_id)

    case PlayerStatsAPI.fetch_player_summary(profile_id) do
      {:ok, stats} ->
        {:noreply,
         socket
         |> assign(
           profile_id: profile_id,
           name: stats["name"],
           avatar: get_in(stats, ["avatars", "medium"]),
           url: stats["site_url"],
           rank: get_in(stats, ["modes", "rm_solo", "rank"]),
           wr: get_in(stats, ["modes", "rm_solo", "win_rate"]),
           error: nil,
           show_search: false,
           current_url: url(socket, ~p"/player/#{profile_id}/rating"),
           country_code: stats["country"]
         )
         |> WololoWeb.SEO.assign_player()}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(
           error: reason,
           profile_id: profile_id,
           show_search: false,
           country_code: nil
         )}
    end
  end

  def get_country_code_emoji(nil), do: nil

  def get_country_code_emoji(country_code) when is_binary(country_code) do
    country_code
    |> String.upcase()
    |> String.to_charlist()
    |> Enum.map(fn char_code -> char_code + 127_397 end)
    |> List.to_string()
  end

  @impl true
  def handle_params(params, _uri, socket) do
    active =
      case params["section"] do
        "opponents" -> :opponents
        "rating" -> :rating
        "insights" -> :insights
        "game_length" -> :game_length
        "rank" -> :rank
        "analysis" -> :analysis
        _ -> :rating
      end

    {:noreply, socket |> assign(active: active) |> WololoWeb.SEO.assign_player()}
  end

  defp hydrate_from_leaderboard(socket, profile_id) do
    case Wololo.LeaderboardDumpCron.get_player(profile_id) do
      {:ok, player} ->
        wr =
          cond do
            is_integer(player.games_count) and player.games_count > 0 and
                is_integer(player.wins_count) ->
              Float.round(player.wins_count / player.games_count * 100, 1)

            true ->
              nil
          end

        assign(socket,
          name: player.name,
          rank: player.rank,
          country_code: empty_to_nil(player.country),
          wr: wr
        )

      _ ->
        socket
    end
  end

  defp empty_to_nil(nil), do: nil
  defp empty_to_nil(""), do: nil
  defp empty_to_nil(value) when is_binary(value), do: value
  defp empty_to_nil(_), do: nil

  def render_section(assigns) do
    if(!assigns.profile_id) do
      ~H"""
      <div class="flex justify-center items-center h-full">
        <div class="spinner spinner-primary"></div>
      </div>
      """
    else
      case assigns.active do
        :rating ->
          ~H"""
          <.live_component module={RatingLive} id="rating" profile_id={@profile_id} />
          """

        :rank ->
          ~H"""
          <.live_component module={RankLive} id="rank" profile_id={@profile_id} />
          """

        :analysis ->
          ~H"""
          <.live_component module={AnalysisLive} id="analysis" profile_id={@profile_id} />
          """

        :game_length ->
          ~H"""
          <.live_component
            module={GameLengthLive}
            id="game-length"
            profile_id={@profile_id}
            player_name={@name}
          />
          """

        :opponents ->
          ~H"""
          <.live_component
            module={OpponentsByCountryLive}
            id="opponents-by-country"
            profile_id={@profile_id}
          />
          """

        :insights ->
          ~H"""
          <.live_component module={InsightsLive} id="insights" profile_id={@profile_id} player_name={@name} />
          """

        _ ->
          ~H"""
          <div>Unknown section</div>
          """
      end
    end
  end
end
