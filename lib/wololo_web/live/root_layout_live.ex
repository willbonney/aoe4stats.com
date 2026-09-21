defmodule WololoWeb.RootLayoutLive do
  import Phoenix.Component
  import Phoenix.LiveView

  def on_mount(:default, _params, _session, socket) do
    if Phoenix.LiveView.connected?(socket) do
      Phoenix.PubSub.subscribe(Wololo.PubSub, "global:search")
    end

    socket =
      socket
      |> WololoWeb.SEO.assign_defaults()
      |> attach_hook(:handle_search_events, :handle_event, &handle_search_event/3)
      |> attach_hook(:handle_search_info, :handle_info, &handle_search_info/2)
      |> attach_hook(:seo_canonical, :handle_params, &handle_seo_params/3)
      |> assign(show_search: false)

    {:cont, socket}
  end

  defp handle_seo_params(_params, uri, socket) do
    {:cont, WololoWeb.SEO.assign_canonical_from_uri(socket, uri)}
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
