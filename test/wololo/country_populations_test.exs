defmodule Wololo.CountryPopulationsTest do
  use ExUnit.Case, async: true

  alias Wololo.CountryPopulations

  test "looks up ISO country populations" do
    assert CountryPopulations.get_population("us") == 339.0
    assert CountryPopulations.get_population("US") == 339.0
    assert CountryPopulations.get_population("zz") == nil
    assert CountryPopulations.has_data?("de")
    refute CountryPopulations.has_data?("zz")
  end
end
