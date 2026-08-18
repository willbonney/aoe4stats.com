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

  describe "MapPool.filter_maps/2" do
    test "keeps only maps in the current pool, case-insensitive" do
      maps = [%{name: "Dry Arabia"}, %{name: "Altai"}, %{name: "Gorge"}]
      pool = MapSet.new(["dry arabia", "gorge"])

      assert Enum.map(Wololo.MapPool.filter_maps(maps, pool), & &1.name) == [
               "Dry Arabia",
               "Gorge"
             ]
    end

    test "returns all maps when the pool is empty" do
      maps = [%{name: "Altai"}, %{name: "Gorge"}]
      assert Wololo.MapPool.filter_maps(maps, MapSet.new()) == maps
    end
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

  describe "resolved_chart_map/2" do
    test "keeps the current map when it is still visible" do
      maps = [%{name: "Gorge"}, %{name: "Altai"}]
      assert CivsByMapLive.resolved_chart_map(maps, "Altai") == "Altai"
    end

    test "falls back to the first map when the current one is gone" do
      maps = [%{name: "Gorge"}, %{name: "Altai"}]
      assert CivsByMapLive.resolved_chart_map(maps, "Dry Arabia") == "Gorge"
    end

    test "returns nil when there are no maps" do
      assert CivsByMapLive.resolved_chart_map([], "Gorge") == nil
    end
  end

  describe "favored_rows/3" do
    test "sorts selected civs by win rate descending and skips N/A" do
      map =
        map("Dry Arabia", english: "55.00%", french: "40.00%", rus: "N/A")

      civs = [
        %{key: :name, label: "Map"},
        %{key: :english, label: "English", image: "english"},
        %{key: :french, label: "French", image: "french"},
        %{key: :rus, label: "Rus", image: "rus"}
      ]

      rows = CivsByMapLive.favored_rows(map, MapSet.new([:english, :french, :rus]), civs)

      assert Enum.map(rows, & &1.label) == ["English", "French"]
      assert hd(rows).image == "english"
      assert hd(rows).delta == 5.0
      assert List.last(rows).delta == -10.0
    end

    test "returns an empty list without a map" do
      assert CivsByMapLive.favored_rows(nil, MapSet.new([:english]), []) == []
    end
  end

  describe "variance_rows/3" do
    test "computes min, max, average, and range across maps" do
      maps = [
        map("Altai", english: "45.00%", french: "60.00%"),
        map("Dry Arabia", english: "55.00%", french: "40.00%"),
        map("Gorge", english: "N/A", french: "50.00%")
      ]

      civs = [
        %{key: :name, label: "Map", image: nil},
        %{key: :english, label: "English", image: "english"},
        %{key: :french, label: "French", image: "french"}
      ]

      rows = CivsByMapLive.variance_rows(maps, MapSet.new([:english, :french]), civs)

      assert Enum.map(rows, & &1.label) == ["French", "English"]

      french = hd(rows)
      assert french.min == 40.0
      assert french.max == 60.0
      assert french.avg == 50.0
      assert french.range == 20.0
      assert french.min_map == "Dry Arabia"
      assert french.max_map == "Altai"

      english = List.last(rows)
      assert english.range == 10.0
      assert english.avg == 50.0
    end
  end

  describe "best_civ_on_map/3" do
    test "returns the selected civ with the highest win rate" do
      map = map("Dry Arabia", english: "55.00%", french: "40.00%", rus: "60.00%")

      civs = [
        %{key: :name, label: "Map", image: nil},
        %{key: :english, label: "English", image: "english"},
        %{key: :french, label: "French", image: "french"},
        %{key: :rus, label: "Rus", image: "rus"}
      ]

      best = CivsByMapLive.best_civ_on_map(map, MapSet.new([:english, :french, :rus]), civs)
      assert best.key == :rus
      assert best.image == "rus"
    end

    test "ignores civs that are not selected" do
      map = map("Dry Arabia", english: "55.00%", french: "40.00%", rus: "60.00%")

      civs = [
        %{key: :name, label: "Map", image: nil},
        %{key: :english, label: "English", image: "english"},
        %{key: :french, label: "French", image: "french"},
        %{key: :rus, label: "Rus", image: "rus"}
      ]

      best = CivsByMapLive.best_civ_on_map(map, MapSet.new([:english, :french]), civs)
      assert best.key == :english
    end

    test "returns nil when no civ has a win rate" do
      map = map("Dry Arabia", english: "N/A")

      civs = [
        %{key: :name, label: "Map", image: nil},
        %{key: :english, label: "English", image: "english"}
      ]

      assert CivsByMapLive.best_civ_on_map(map, MapSet.new([:english]), civs) == nil
    end
  end
end
