defmodule WololoWeb.ErrorHelpers do
  @moduledoc """
  Utility functions for formatting and displaying errors in templates.
  """

  @doc """
  Formats an error for display in templates.

  Handles various error formats and returns a safe string representation:
  - `{:error, message}` tuples - extracts the message
  - Plain strings - returns as-is
  - Other values - converts to string via inspect/1

  ## Examples

      iex> format_error({:error, "Something went wrong"})
      "Something went wrong"

      iex> format_error("Plain error message")
      "Plain error message"

      iex> format_error(%{unexpected: "format"})
      ~s(%{unexpected: "format"})

  """
  @spec format_error(term()) :: String.t()
  def format_error({:error, message}) when is_binary(message), do: message
  def format_error(message) when is_binary(message), do: message
  def format_error(other), do: inspect(other)
end
