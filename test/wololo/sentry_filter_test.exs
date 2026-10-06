defmodule Wololo.SentryFilterTest do
  use ExUnit.Case, async: true

  alias Wololo.SentryFilter

  defp event(attrs) do
    struct!(
      Sentry.Event,
      Map.merge(
        %{event_id: String.duplicate("a", 32), timestamp: "2026-01-01T00:00:00Z"},
        attrs
      )
    )
  end

  test "drops Bandit disconnects and keeps real exceptions" do
    transport = event(%{original_exception: %Bandit.TransportError{message: "closed"}})
    assert SentryFilter.before_send(transport) == false

    http = event(%{original_exception: %Bandit.HTTPError{message: "bad", plug_status: 400}})
    assert SentryFilter.before_send(http) == false

    typed = event(%{exception: [%{type: "Bandit.TransportError"}]})
    assert SentryFilter.before_send(typed) == false

    message = event(%{message: "Unrecoverable error: closed"})
    assert SentryFilter.before_send(message) == false

    formatted = event(%{message: %{formatted: "Bandit.HTTPError: closed"}})
    assert SentryFilter.before_send(formatted) == false

    runtime = event(%{original_exception: %RuntimeError{message: "boom"}, message: "boom"})
    assert SentryFilter.before_send(runtime) == runtime
  end
end
