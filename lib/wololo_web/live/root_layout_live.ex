defmodule WololoWeb.RootLayoutLive do
  import Phoenix.Component
  import Phoenix.LiveView

  def on_mount(:default, _params, _session, socket) do
    if Phoenix.LiveView.connected?(socket) do
      Phoenix.PubSub.subscribe(Wololo.PubSub, "global:search")
    end

    socket =
      socket
      |> attach_hook(:handle_search_events, :handle_event, &handle_search_event/3)
      |> attach_hook(:handle_search_info, :handle_info, &handle_search_info/2)
      |> assign(show_search: false, hosting_cost: Wololo.FlyCost.cached())

    {:cont, socket}
  end

  defp handle_search_event("show_search", _params, socket) do
    {:halt, assign(socket, show_search: true)}
  end

  defp handle_search_event("close_search", _params, socket) do
    {:halt, assign(socket, show_search: false)}
  end

  defp handle_search_event(_event, _params, socket) do
    {:cont, socket}
  end

  defp handle_search_info({:show_search}, socket) do
    {:halt, assign(socket, show_search: true)}
  end

  defp handle_search_info(_msg, socket) do
    {:cont, socket}
  end
end
