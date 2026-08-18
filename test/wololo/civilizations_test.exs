defmodule Wololo.CivilizationsTest do
  use ExUnit.Case, async: true

  alias Wololo.Civilizations

  test "lists unique slugs, keys, and labels" do
    slugs = Civilizations.slugs()
    keys = Civilizations.keys()

    assert length(slugs) == length(Enum.uniq(slugs))
    assert length(keys) == length(Enum.uniq(keys))
    assert length(slugs) == length(keys)
    assert "french" in slugs
    assert "delhi_sultanate" in slugs
    assert :jin_dynasty in keys
  end

  test "parse_key maps slugs to atoms and rejects unknown values" do
    assert Civilizations.parse_key("french") == :french
    assert Civilizations.parse_key("delhi_sultanate") == :delhi_sultanate
    assert Civilizations.parse_key("not_a_civ") == nil
    assert Civilizations.parse_key(nil) == nil
  end

  test "table_civs prepends the name column" do
    [first | rest] = Civilizations.table_civs()
    assert first == %{key: :name, label: "Civ", image: nil}
    assert length(rest) == length(Civilizations.all())
  end
end
