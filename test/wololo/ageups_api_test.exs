defmodule Wololo.AgeupsAPITest do
  use ExUnit.Case, async: false

  alias Wololo.AgeupsAPI
  alias Wololo.AgeupsFixtures

  setup do
    Cachex.clear(:wololo_cache)
    :ok
  end

  test "parses complete paths and ignores incomplete ones" do
    paths = AgeupsAPI.parse_paths(AgeupsFixtures.payload(), "french")
    assert length(paths) == 2
    assert Enum.all?(paths, & &1.age2.name)
    assert Enum.all?(paths, & &1.age3.name)
    assert Enum.all?(paths, & &1.age4.name)
    assert AgeupsAPI.parse_paths(AgeupsFixtures.payload(), "unknown") == []
  end

  test "recommends the highest win rate path with enough games" do
    rec = AgeupsAPI.recommend(AgeupsAPI.parse_paths(AgeupsFixtures.payload(), "french"))
    assert rec.path.age2.name == "School of Cavalry"
    assert rec.path.age3.name == "Guild Hall"
    assert rec.path.age4.name == "Red Palace"
    assert hd(rec.alternatives).age2.name == "Chamber of Commerce"
  end

  test "falls back to smaller samples when nothing has 100 games" do
    paths = [
      %{
        civilization: "french",
        win_rate: 70.0,
        games: 40,
        wins: 28,
        duration_average: 1400,
        age2: %{age: 2, name: "Rare", pbgid: 1, icon: nil, finished_at: 200},
        age3: %{age: 3, name: "Rare Castle", pbgid: 2, icon: nil, finished_at: 700},
        age4: %{age: 4, name: "Rare Imp", pbgid: 3, icon: nil, finished_at: 1400}
      },
      %{
        civilization: "french",
        win_rate: 55.0,
        games: 30,
        wins: 16,
        duration_average: 1400,
        age2: %{age: 2, name: "Common-ish", pbgid: 4, icon: nil, finished_at: 200},
        age3: %{age: 3, name: "Castle", pbgid: 5, icon: nil, finished_at: 700},
        age4: %{age: 4, name: "Imp", pbgid: 6, icon: nil, finished_at: 1400}
      }
    ]

    rec = AgeupsAPI.recommend(paths)
    assert rec.path.age2.name == "Rare"
  end

  test "returns an empty recommendation when there are no paths" do
    assert AgeupsAPI.recommend([]) == %{path: nil, alternatives: [], matchup: nil, civ_matchup: nil}
  end

  test "cleans landmark names with newlines" do
    payload = %{
      "data" => %{
        "age1-4" => [
          AgeupsFixtures.complete_row(
            "ayyubids",
            55.0,
            200,
            1,
            "Logistics\n(Feudal Culture Wing)",
            2,
            "Culture",
            3,
            "Military"
          )
        ]
      }
    }

    [path] = AgeupsAPI.parse_paths(payload, "ayyubids")
    assert path.age2.name == "Logistics (Feudal Culture Wing)"
  end

  test "formats landmark timing as a clock" do
    assert AgeupsAPI.format_clock(283) == "4:43"
    assert AgeupsAPI.format_clock(nil) == nil
  end

  test "warm_from_payload stores paths and any-opponent recommendations" do
    assert {:ok, info} = AgeupsAPI.warm_from_payload(AgeupsFixtures.options(), AgeupsFixtures.payload())
    assert info.civs == 2
    assert info.patch == AgeupsFixtures.patch()
    assert info.recommendations > 0

    assert {:ok, paths} = AgeupsAPI.fetch_paths("french", AgeupsFixtures.patch())
    assert length(paths) == 2

    assert {:ok, rec} = AgeupsAPI.recommend_for("french", nil, AgeupsFixtures.patch())
    assert rec.path.age2.name == "School of Cavalry"
    assert {:ok, %DateTime{}} = AgeupsAPI.last_updated()
  end

  test "refresh_cache pulls options and paths through the HTTP client" do
    previous = Application.get_env(:wololo, :http_client)
    Application.put_env(:wololo, :http_client, Wololo.FakeHTTP)

    on_exit(fn ->
      if previous do
        Application.put_env(:wololo, :http_client, previous)
      else
        Application.delete_env(:wololo, :http_client)
      end
    end)

    assert {:ok, info} = AgeupsAPI.refresh_cache()
    assert info.patch == AgeupsFixtures.patch()
    assert info.civs == 2
    assert info.matchups > 0
    assert info.recommendations > 0

    assert {:ok, rec} = AgeupsAPI.cached_recommendation("french", nil, AgeupsFixtures.patch())
    assert rec.path.age4.name == "Red Palace"
    assert {:ok, vs} = AgeupsAPI.cached_recommendation("french", "english", AgeupsFixtures.patch())
    assert vs.matchup.win_rate == 61.0
    assert vs.civ_matchup.win_rate == 47.5
    assert vs.civ_matchup.games == 800

    assert info.maps == 1
    assert info.map_combos > 0

    assert {:ok, on_map} =
             AgeupsAPI.cached_recommendation(
               "french",
               nil,
               AgeupsFixtures.patch(),
               AgeupsFixtures.dry_arabia_id()
             )

    assert on_map.path.age2.name == "Chamber of Commerce"
  end

  test "warm_from_payload caches a different recommendation for a season map" do
    maps = [%{id: AgeupsFixtures.dry_arabia_id(), name: "Dry Arabia"}]

    assert {:ok, info} =
             AgeupsAPI.warm_from_payload(AgeupsFixtures.options(), AgeupsFixtures.payload(),
               maps: maps,
               map_payloads: %{AgeupsFixtures.dry_arabia_id() => AgeupsFixtures.map_payload()}
             )

    assert info.maps == 1
    assert info.map_combos == length(Wololo.Civilizations.slugs())

    assert {:ok, any} = AgeupsAPI.recommend_for("french", nil, AgeupsFixtures.patch())
    assert any.path.age2.name == "School of Cavalry"

    assert {:ok, on_map} =
             AgeupsAPI.recommend_for(
               "french",
               nil,
               AgeupsFixtures.patch(),
               AgeupsFixtures.dry_arabia_id()
             )

    assert on_map.path.age2.name == "Chamber of Commerce"
    assert on_map.path.win_rate == 62.0
  end

  test "refresh_cache returns the HTTP error instead of writing a partial cache" do
    previous = Application.get_env(:wololo, :http_client)
    Application.put_env(:wololo, :http_client, Wololo.FakeHTTP.Failing)

    on_exit(fn ->
      if previous do
        Application.put_env(:wololo, :http_client, previous)
      else
        Application.delete_env(:wololo, :http_client)
      end
    end)

    assert {:error, reason} = AgeupsAPI.refresh_cache()
    assert reason =~ "boom"
    assert {:error, :not_found} = AgeupsAPI.last_updated()
  end

  test "fetch_options and fetch_paths hydrate from HTTP on a cache miss" do
    previous = Application.get_env(:wololo, :http_client)
    Application.put_env(:wololo, :http_client, Wololo.FakeHTTP)

    on_exit(fn ->
      if previous do
        Application.put_env(:wololo, :http_client, previous)
      else
        Application.delete_env(:wololo, :http_client)
      end
    end)

    assert {:ok, options} = AgeupsAPI.fetch_options()
    assert options.patch == AgeupsFixtures.patch()
    assert options.patch_label == "Test Patch"

    assert {:ok, paths} = AgeupsAPI.fetch_paths("french", AgeupsFixtures.patch())
    assert length(paths) == 2
    assert hd(paths).age2.name == "School of Cavalry"
  end

  test "opponent rec falls back to overall best when matchup samples are thin" do
    {:ok, _} = AgeupsAPI.warm_from_payload(AgeupsFixtures.options(), AgeupsFixtures.payload())
    paths = AgeupsAPI.parse_paths(AgeupsFixtures.payload(), "french")
    popular = Enum.find(paths, &(&1.age2.name == "School of Cavalry"))
    counter = Enum.find(paths, &(&1.age2.name == "Chamber of Commerce"))

    thin = fn wr ->
      [%{opponent: "english", win_rate: wr, games: 5, wins: 3, duration_average: 1400}]
    end

    Cachex.put(
      :wololo_cache,
      "ageups_mu_#{AgeupsFixtures.patch()}_french_#{popular.age2.pbgid}_#{popular.age3.pbgid}_#{popular.age4.pbgid}",
      {:ok, thin.(90.0)}
    )

    Cachex.put(
      :wololo_cache,
      "ageups_mu_#{AgeupsFixtures.patch()}_french_#{counter.age2.pbgid}_#{counter.age3.pbgid}_#{counter.age4.pbgid}",
      {:ok, thin.(80.0)}
    )

    AgeupsAPI.cache_recommendations(%{"french" => paths}, AgeupsFixtures.patch())
    assert {:ok, rec} = AgeupsAPI.recommend_for("french", "english", AgeupsFixtures.patch())
    assert rec.path.age2.name == "School of Cavalry"
    refute rec.matchup && rec.matchup.games >= 20
  end

  test "cached opponent recommendations prefer the stronger matchup path" do
    {:ok, _} = AgeupsAPI.warm_from_payload(AgeupsFixtures.options(), AgeupsFixtures.payload())
    paths = AgeupsAPI.parse_paths(AgeupsFixtures.payload(), "french")
    popular = Enum.find(paths, &(&1.age2.name == "School of Cavalry"))
    counter = Enum.find(paths, &(&1.age2.name == "Chamber of Commerce"))

    Cachex.put(
      :wololo_cache,
      "ageups_mu_#{AgeupsFixtures.patch()}_french_#{popular.age2.pbgid}_#{popular.age3.pbgid}_#{popular.age4.pbgid}",
      {:ok,
       [%{opponent: "english", win_rate: 48.0, games: 200, wins: 96, duration_average: 1400}]}
    )

    Cachex.put(
      :wololo_cache,
      "ageups_mu_#{AgeupsFixtures.patch()}_french_#{counter.age2.pbgid}_#{counter.age3.pbgid}_#{counter.age4.pbgid}",
      {:ok,
       [%{opponent: "english", win_rate: 61.0, games: 80, wins: 49, duration_average: 1550}]}
    )

    AgeupsAPI.cache_recommendations(%{"french" => paths}, AgeupsFixtures.patch())
    assert {:ok, rec} = AgeupsAPI.recommend_for("french", "english", AgeupsFixtures.patch())
    assert rec.path.age2.name == "Chamber of Commerce"
    assert rec.matchup.win_rate == 61.0
    assert hd(rec.alternatives).age2.name == "School of Cavalry"
    assert hd(rec.alternatives).win_rate == 48.0
    assert hd(rec.alternatives).games == 200
  end
end
