defmodule Wololo.MapPoolTest do
  use ExUnit.Case, async: false

  alias Wololo.AgeupsFixtures
  alias Wololo.MapPool

  setup do
    Cachex.clear(:wololo_cache)
    previous = Application.get_env(:wololo, :http_client)
    Application.put_env(:wololo, :http_client, Wololo.FakeHTTP)

    on_exit(fn ->
      if previous do
        Application.put_env(:wololo, :http_client, previous)
      else
        Application.delete_env(:wololo, :http_client)
      end
    end)

    :ok
  end

  test "normalizes map names for pool membership" do
    assert MapPool.normalize_name(" Dry Arabia ") == "dry arabia"
    assert MapPool.normalize_name(nil) == ""
  end

  test "filter_maps keeps only names in the current pool" do
    maps = [%{name: "Dry Arabia"}, %{name: "Gorge"}, %{name: "Altai"}]
    pool = MapSet.new(["dry arabia", "gorge"])

    assert Enum.map(MapPool.filter_maps(maps, pool), & &1.name) == ["Dry Arabia", "Gorge"]
    assert MapPool.filter_maps(maps, MapSet.new()) == maps
  end

  test "refresh stores season map ids from the HTTP client" do
    assert {:ok, %{maps: maps}} = MapPool.refresh()
    assert [%{name: "Dry Arabia", id: id}] = maps
    assert id == AgeupsFixtures.dry_arabia_id()
    assert {:ok, %{maps: ^maps}} = MapPool.get()
  end
end
