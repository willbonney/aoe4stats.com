defmodule Wololo.SentryFilter do
  @moduledoc """
  Drops expected transport noise from Sentry.

  `Bandit.TransportError` / `Bandit.HTTPError` are raised when clients disconnect
  mid-request (tab close, navigation, flaky network). Bandit rescues them
  internally; Sentry still sees them via PlugCapture / LoggerHandler.
  See https://github.com/mtrudel/bandit/issues/456
  """

  @noise_exception_modules [Bandit.TransportError, Bandit.HTTPError]
  @noise_type_names MapSet.new(Enum.map(@noise_exception_modules, &inspect/1))

  @doc """
  Sentry `:before_send` callback. Returns `false` to drop the event.
  """
  @spec before_send(Sentry.Event.t()) :: Sentry.Event.t() | false
  def before_send(%Sentry.Event{} = event) do
    if noise?(event), do: false, else: event
  end

  defp noise?(%Sentry.Event{} = event) do
    noise_original_exception?(event.original_exception) or
      noise_exception_values?(event.exception) or
      noise_message?(event)
  end

  defp noise_original_exception?(%mod{}) when mod in @noise_exception_modules, do: true
  defp noise_original_exception?(_), do: false

  defp noise_exception_values?(exceptions) when is_list(exceptions) do
    Enum.any?(exceptions, fn
      %{type: type} when is_binary(type) -> type in @noise_type_names
      _ -> false
    end)
  end

  defp noise_exception_values?(_), do: false

  # LoggerHandler crash reports sometimes only carry the message text
  defp noise_message?(%Sentry.Event{message: message}) do
    noise_text?(message)
  end

  defp noise_text?(message) when is_binary(message) do
    String.contains?(message, "Bandit.TransportError") or
      String.contains?(message, "Bandit.HTTPError") or
      String.contains?(message, "Unrecoverable error: closed")
  end

  defp noise_text?(%{formatted: formatted}) when is_binary(formatted) do
    noise_text?(formatted)
  end

  defp noise_text?(_), do: false
end
