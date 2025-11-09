defmodule WololoWeb.GameLengthLive do
  use WololoWeb, :live_component
  alias Wololo.PlayerGamesAPI
  import WololoWeb.Components.Spinner

  @impl true
  def mount(socket) do
    {:ok, socket |> assign(error: nil)}
  end

  @impl true
  def update(assigns, socket) do
    profile_id = assigns[:profile_id]
    Sentry.Context.set_user_context(%{id: profile_id})
    assign(socket, loading: true)

    case PlayerGamesAPI.get_player_wr_by_game_length(profile_id) do
      {:ok, wrs} ->
        {
          :ok,
          socket
          |> assign(wrs: wrs, loading: false, error: nil)
          |> push_event("update-wrs", %{byLength: wrs})
        }

      {:error, reason} ->
        {
          :ok,
          socket
          |> assign(wrs: [], loading: false, error: reason)
        }
    end
  end
end
