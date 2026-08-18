defmodule Wololo.FakeHTTP do
  def get_with_retry(url, _headers \\ [], _retries \\ 0) do
    cond do
      String.contains?(url, "query_options") ->
        {:ok, Jason.encode!(Wololo.AgeupsFixtures.query_options_json())}

      String.contains?(url, "ageups/matchups") and not String.contains?(url, "age2_pbgid") ->
        {:ok, Jason.encode!(Wololo.AgeupsFixtures.civ_matchups_json())}

      String.contains?(url, "ageups/matchups") ->
        {:ok, Jason.encode!(Wololo.AgeupsFixtures.matchups_json())}

      String.contains?(url, "stats/analytics/ageups") and map_specific?(url) ->
        {:ok, Jason.encode!(Wololo.AgeupsFixtures.map_payload())}

      String.contains?(url, "stats/analytics/ageups") ->
        {:ok, Jason.encode!(Wololo.AgeupsFixtures.payload())}

      String.contains?(url, "mappool") ->
        {:ok,
         Jason.encode!(%{
           "maps" => [%{"map_name" => "Dry Arabia", "map_id" => Wololo.AgeupsFixtures.dry_arabia_id()}]
         })}

      true ->
        {:error, "unexpected url: #{url}"}
    end
  end

  defp map_specific?(url) do
    String.contains?(url, "map_id=")
  end
end

defmodule Wololo.FakeHTTP.Failing do
  def get_with_retry(_url, _headers \\ [], _retries \\ 0), do: {:error, "boom"}
end
