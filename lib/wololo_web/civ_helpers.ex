defmodule WololoWeb.CivHelpers do
  alias Wololo.Cldr

  def parse_win_rate(nil), do: nil
  def parse_win_rate("N/A"), do: nil
  def parse_win_rate(rate) when is_number(rate), do: rate / 1

  def parse_win_rate(rate) when is_binary(rate) do
    case Float.parse(rate) do
      {value, _} -> value
      :error -> nil
    end
  end

  def parse_win_rate(_), do: nil

  def format_win_rate(nil), do: "N/A"

  def format_win_rate(win_rate) when is_number(win_rate) and win_rate >= 0 and win_rate <= 100 do
    :io_lib.format("~.2f%", [win_rate / 1]) |> to_string()
  end

  def format_win_rate(_), do: "N/A"

  def format_duration(nil), do: nil

  def format_duration(seconds) when is_number(seconds) do
    "#{div(round(seconds), 60)}m"
  end

  def format_duration(_), do: nil

  def format_number(nil), do: "N/A"

  def format_number(number) when is_integer(number) do
    case Cldr.Number.to_string(number) do
      {:ok, formatted} -> formatted
      {:error, _} -> Integer.to_string(number)
    end
  end

  def format_number(number), do: number

  def color_class(percentage, type) when is_binary(percentage) do
    case Float.parse(percentage) do
      {value, "%"} -> color_class(value, type)
      _ -> if(type == :bg, do: "bg-gray-100", else: "text-gray-600")
    end
  end

  def color_class(percentage, type) when is_number(percentage) and type in [:bg, :text] do
    prefix = if type == :bg, do: "bg", else: "text"

    cond do
      percentage < 39 -> "#{prefix}-red-700"
      percentage < 42 -> "#{prefix}-red-600"
      percentage < 45 -> "#{prefix}-red-500"
      percentage < 47 -> "#{prefix}-red-400"
      percentage < 49 -> "#{prefix}-red-300"
      percentage < 50 -> "#{prefix}-red-200"
      percentage == 50 -> "#{prefix}-gray-200"
      percentage < 51 -> "#{prefix}-green-200"
      percentage < 53 -> "#{prefix}-green-300"
      percentage < 55 -> "#{prefix}-green-400"
      percentage < 60 -> "#{prefix}-green-500"
      percentage < 65 -> "#{prefix}-green-600"
      percentage < 70 -> "#{prefix}-green-700"
      true -> "#{prefix}-green-700"
    end
  end

  def color_class(_, type) when type in [:bg, :text] do
    if type == :bg, do: "bg-gray-100", else: "text-gray-600"
  end

  def duration_color_class(seconds) when is_number(seconds) do
    minutes = seconds / 60

    cond do
      minutes < 20 -> "bg-sky-200"
      minutes < 22 -> "bg-sky-300"
      minutes < 24 -> "bg-blue-300"
      minutes < 26 -> "bg-blue-400"
      minutes < 28 -> "bg-indigo-400"
      true -> "bg-indigo-500"
    end
  end

  def duration_color_class(_), do: "bg-gray-100"
end
