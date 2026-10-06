defmodule WololoWeb.CoreComponentsTest do
  use ExUnit.Case, async: true

  alias WololoWeb.CoreComponents

  test "translates errors and exposes shared classes" do
    assert CoreComponents.translate_error({"is invalid", []}) == "is invalid"

    assert CoreComponents.translate_errors([name: {"can't be blank", []}, rank: {"is invalid", []}], :name) ==
             ["can't be blank"]

    assert CoreComponents.card_class_padded() =~ "p-6"
    assert CoreComponents.tab_active() =~ "border-blue-500"
  end
end
