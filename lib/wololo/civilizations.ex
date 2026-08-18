defmodule Wololo.Civilizations do
  @civs [
    %{key: :abbasid_dynasty, slug: "abbasid_dynasty", label: "Abbasid", image: "abbasid_dynasty", color: "#37474F"},
    %{key: :chinese, slug: "chinese", label: "Chinese", image: "chinese", color: "#E53935"},
    %{key: :delhi_sultanate, slug: "delhi_sultanate", label: "Delhi", image: "delhi_sultanate", color: "#2E7D32"},
    %{key: :english, slug: "english", label: "English", image: "english", color: "#EF5350"},
    %{key: :french, slug: "french", label: "French", image: "french", color: "#1565C0"},
    %{key: :holy_roman_empire, slug: "holy_roman_empire", label: "HRE", image: "holy_roman_empire", color: "#F9A825"},
    %{key: :mongols, slug: "mongols", label: "Mongols", image: "mongols", color: "#0288D1"},
    %{key: :rus, slug: "rus", label: "Rus", image: "rus", color: "#C62828"},
    %{key: :ottomans, slug: "ottomans", label: "Ottomans", image: "ottomans", color: "#558B2F"},
    %{key: :malians, slug: "malians", label: "Malians", image: "malians", color: "#FF8F00"},
    %{key: :byzantines, slug: "byzantines", label: "Byzantines", image: "byzantines", color: "#7B1FA2"},
    %{key: :japanese, slug: "japanese", label: "Japanese", image: "japanese", color: "#FFB300"},
    %{key: :ayyubids, slug: "ayyubids", label: "Ayyubids", image: "ayyubids", color: "#E65100"},
    %{key: :jeanne_darc, slug: "jeanne_darc", label: "JDA", image: "jeanne_darc", color: "#C0CA33"},
    %{key: :order_of_the_dragon, slug: "order_of_the_dragon", label: "OOTD", image: "order_of_the_dragon", color: "#9E9D24"},
    %{key: :zhu_xis_legacy, slug: "zhu_xis_legacy", label: "ZXL", image: "zhu_xis_legacy", color: "#00897B"},
    %{key: :knights_templar, slug: "knights_templar", label: "KTP", image: "knights_templar", color: "#D32F2F"},
    %{key: :house_of_lancaster, slug: "house_of_lancaster", label: "HOL", image: "house_of_lancaster", color: "#00695C"},
    %{key: :tughlaq_dynasty, slug: "tughlaq_dynasty", label: "Tughlaq", image: "tughlaq_dynasty", color: "#78909C"},
    %{key: :sengoku_daimyo, slug: "sengoku_daimyo", label: "Sengoku", image: "sengoku_daimyo", color: "#D84315"},
    %{key: :macedonian_dynasty, slug: "macedonian_dynasty", label: "Macedonian", image: "macedonian_dynasty", color: "#AD1457"},
    %{key: :golden_horde, slug: "golden_horde", label: "GOH", image: "golden_horde", color: "#FF1744"},
    %{key: :jin_dynasty, slug: "jin_dynasty", label: "JIN", image: "jin_dynasty", color: "#E8E43B"}
  ]

  def all, do: @civs
  def slugs, do: Enum.map(@civs, & &1.slug)
  def keys, do: Enum.map(@civs, & &1.key)

  def table_civs do
    [%{key: :name, label: "Civ", image: nil}] ++ @civs
  end

  def parse_key(slug) when is_binary(slug) do
    Enum.find_value(@civs, fn civ -> if civ.slug == slug, do: civ.key end)
  end

  def parse_key(_), do: nil
end
