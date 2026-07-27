defmodule WololoWeb.SearchComponent do
  use WololoWeb, :live_component
  import WololoWeb.CustomComponents
  import Wololo.SearchPlayerAPI

  @impl true
  def mount(socket) do
    {:ok, assign(socket, search: "", players: [], has_searched: false)}
  end

  @impl true
  def handle_event("do-search", %{"value" => value}, socket) do
    case fetch_player(value) do
      {:ok, data} ->
        {
          :noreply,
          socket
          |> assign(search: value, players: data["players"], has_searched: true)
        }

      {:error, reason} ->
        {
          :noreply,
          socket
          |> assign(search: value, players: [], has_searched: true)
          |> put_flash(:error, "Search failed: #{reason}")
        }
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="search-component">
      <.search_modal
        show={assigns[:show]}
        id="search-modal"
        on_cancel={@on_cancel}
        allow_outside_clicks={false}
      >
        <.search_input phx-target={@myself} phx-keyup="do-search" phx-debounce="200" />
        <.search_results players={@players} has_searched={@has_searched} />
      </.search_modal>
    </div>
    """
  end
end
