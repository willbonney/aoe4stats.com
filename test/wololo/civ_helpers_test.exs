defmodule WololoWeb.CivHelpersTest do
  use ExUnit.Case, async: true

  alias WololoWeb.CivHelpers

  test "parses and formats win rates" do
    assert CivHelpers.parse_win_rate("52.34%") == 52.34
    assert CivHelpers.parse_win_rate(51) == 51.0
    assert CivHelpers.parse_win_rate(nil) == nil
    assert CivHelpers.parse_win_rate("N/A") == nil
    assert CivHelpers.format_win_rate(58.5) == "58.50%"
    assert CivHelpers.format_win_rate(nil) == "N/A"
    assert CivHelpers.format_win_rate(200) == "N/A"
  end

  test "picks red-to-green classes around 50%" do
    assert CivHelpers.color_class(40, :text) == "text-red-600"
    assert CivHelpers.color_class(50, :text) == "text-gray-200"
    assert CivHelpers.color_class(61, :bg) == "bg-green-600"
    assert CivHelpers.color_class("oops", :text) == "text-gray-600"
  end

  test "formats durations, numbers, and game-length colors" do
    assert CivHelpers.format_duration(1589) == "26m"
    assert CivHelpers.format_duration(nil) == nil
    assert CivHelpers.format_number(6582) == "6,582"
    assert CivHelpers.format_number(nil) == "N/A"
    assert CivHelpers.duration_color_class(1500) == "bg-blue-400"
    assert CivHelpers.duration_color_class(nil) == "bg-gray-100"
  end
end
