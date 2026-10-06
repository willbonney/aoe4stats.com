defmodule WololoWeb.ErrorHelpersTest do
  use ExUnit.Case, async: true

  import WololoWeb.ErrorHelpers

  doctest WololoWeb.ErrorHelpers

  test "inspects tuples that are not a binary error message" do
    assert WololoWeb.ErrorHelpers.format_error({:error, :timeout}) == "{:error, :timeout}"
  end
end
