defmodule Wololo.MapPool do
  @moduledoc """
  Cached current RM solo map rotation from AoE4World.

  Fetched at most once per day. On fetch failure, the last good payload is kept.
  """
  require Logger

  @cache_key :rm_solo_mappool
  @stale_key :rm_solo_mappool_stale
  @ttl :timer.hours(24)

  def get_map_names do
    case get() do
      {:ok, %{maps: maps}} ->
        maps
        |> Enum.map(&normalize_name(&1.name))
        |> MapSet.new()

      {:error, _} ->
        MapSet.new()
    end
  end

  def get do
    case Cachex.get(:wololo_cache, @cache_key) do
      {:ok, %{maps: _} = data} -> {:ok, data}
      _ -> refresh()
    end
  end

  def refresh do
    case fetch_remote() do
      {:ok, data} ->
        Cachex.put(:wololo_cache, @cache_key, data, ttl: @ttl)
        Cachex.put(:wololo_cache, @stale_key, data)
        {:ok, data}

      {:error, reason} ->
        case Cachex.get(:wololo_cache, @stale_key) do
          {:ok, %{maps: _} = stale} ->
            Logger.warning("[MapPool] Using stale cache after fetch failure: #{inspect(reason)}")
            {:ok, stale}

          _ ->
            {:error, reason}
        end
    end
  end

  def filter_maps(maps) when is_list(maps) do
    filter_maps(maps, get_map_names())
  end

  def filter_maps(maps, pool) when is_list(maps) do
    if MapSet.size(pool) == 0 do
      maps
    else
      Enum.filter(maps, fn map -> MapSet.member?(pool, normalize_name(map.name)) end)
    end
  end

  def normalize_name(name) when is_binary(name), do: name |> String.downcase() |> String.trim()
  def normalize_name(_), do: ""

  defp fetch_remote do
    url = "#{Application.get_env(:wololo, :api_base_url)}/leaderboards/rm_solo/mappool"
    Logger.info("[MapPool] Fetching current map pool from #{url}")

    http = Application.get_env(:wololo, :http_client, Wololo.HTTPClient)

    case http.get_with_retry(url) do
      {:ok, body} ->
        case Jason.decode(body) do
          {:ok, %{"maps" => maps}} when is_list(maps) ->
            parsed =
              Enum.flat_map(maps, fn
                %{"map_name" => name} when is_binary(name) and name != "" ->
                  [%{name: name}]

                _ ->
                  []
              end)

            {:ok, %{fetched_at: DateTime.utc_now(), maps: parsed}}

          {:ok, _} ->
            {:error, :unexpected_payload}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end
