defmodule WololoWeb.CivsByMapLiveTest do
  use ExUnit.Case, async: true

  alias WololoWeb.CivsByMapLive

  defp map(name, win_rates) do
    civs =
      Map.new(win_rates, fn {civ, win_rate} ->
        {civ, %{win_rate: win_rate, games_count: 10}}
      end)

    %{name: name, civs: civs}
  end

  describe "parse_win_rate/1" do
    test "parses percentage strings" do
      assert CivsByMapLive.parse_win_rate("52.34%") == 52.34
    end

    test "returns nil for missing values" do
      assert CivsByMapLive.parse_win_rate(nil) == nil
      assert CivsByMapLive.parse_win_rate("N/A") == nil
      assert CivsByMapLive.parse_win_rate("oops") == nil
    end
  end

  describe "sorted_maps/4" do
    setup do
      maps = [
        map("Altai", english: "45.00%", french: "60.00%"),
        map("Dry Arabia", english: "55.00%", french: "40.00%"),
        map("Gorge", english: "N/A", french: "50.00%")
      ]

      %{maps: maps}
    end

    test "leaves maps unsorted when no column is selected", %{maps: maps} do
      assert Enum.map(CivsByMapLive.sorted_maps(maps, nil, :desc, MapSet.new()), & &1.name) ==
               ["Altai", "Dry Arabia", "Gorge"]
    end

    test "sorts a civ column descending with N/A last", %{maps: maps} do
      names =
        maps
        |> CivsByMapLive.sorted_maps(:english, :desc, MapSet.new())
        |> Enum.map(& &1.name)

      assert names == ["Dry Arabia", "Altai", "Gorge"]
    end

    test "sorts a civ column ascending with N/A last", %{maps: maps} do
      names =
        maps
        |> CivsByMapLive.sorted_maps(:english, :asc, MapSet.new())
        |> Enum.map(& &1.name)

      assert names == ["Altai", "Dry Arabia", "Gorge"]
    end

    test "sorts by average of selected civs", %{maps: maps} do
      selected = MapSet.new([:english, :french])

      names =
        maps
        |> CivsByMapLive.sorted_maps(:average, :desc, selected)
        |> Enum.map(& &1.name)

      # Altai 52.5, Dry Arabia 47.5, Gorge 50.0 (english N/A ignored)
      assert names == ["Altai", "Gorge", "Dry Arabia"]
    end
  end
end
