#!/bin/bash

# Create a directory to store the flags
mkdir -p aoe4_flags

# Function to download a flag
download_flag() {
    local civ=$1
    local url=$2
    local filename="aoe4_flags/${civ}.png"
    echo "Downloading ${civ} flag..."
    curl -s -o "$filename" "$url"
}

# Download each flag
download_flag "ayyubids" "https://static.aoe4world.com/assets/flags/ayyubids-9ba464806c83e293ac43e19e55dddb80f1fba7b7f5bcb6f7e53b48c4b9c83c9e.png"
download_flag "jeanne_darc" "https://static.aoe4world.com/assets/flags/jeanne_darc-aeec47c19181d6af7b08a015e8a109853d7169d02494b25208d3581e38d022eb.png"
download_flag "order_of_the_dragon" "https://static.aoe4world.com/assets/flags/order_of_the_dragon-cad6fa9212fd59f9b52aaa83b4a6173f07734d38d37200f976bcd46827667424.png"
download_flag "mongols" "https://static.aoe4world.com/assets/flags/mongols-7ce0478ab2ca1f95d0d879fecaeb94119629538e951002ac6cb936433c575105.png"
download_flag "japanese" "https://static.aoe4world.com/assets/flags/japanese-16a9b5bae87a5494d5a002cf7a2c2c5de5cead128a965cbf3a89eeee8292b997.png"
download_flag "delhi_sultanate" "https://static.aoe4world.com/assets/flags/delhi_sultanate-7f92025d0623b8e224533d9f28b9cd7c51a5ff416ef3edaf7cc3e948ee290708.png"
download_flag "zhu_xis_legacy" "https://static.aoe4world.com/assets/flags/zhu_xis_legacy-c4d119a5fc11f2355f41d206a8b65bea8bab2286d09523a81b7d662d1aad0762.png"
download_flag "byzantines" "https://static.aoe4world.com/assets/flags/byzantines-cfe0492a2ed33b486946a92063989a9500ae54d9301178ee55ba6b4d4c7ceb84.png"
download_flag "french" "https://static.aoe4world.com/assets/flags/french-c3474adb98d8835fb5a86b3988d6b963a1ac2a8327d136b11fb0fd0537b45594.png"
download_flag "ottomans" "https://static.aoe4world.com/assets/flags/ottomans-83c752dcbe46ad980f6f65dd719b060f8fa2d0707ab8e2ddb1ae5d468fc019a2.png"
download_flag "abbasid_dynasty" "https://static.aoe4world.com/assets/flags/abbasid_dynasty-b722e3e4ee862226395c692e73cd14c18bc96c3469874d2e0d918305c70f8a69.png"
download_flag "english" "https://static.aoe4world.com/assets/flags/english-8c6c905d0eb11d6d314b9810b2a0b9c09eec69afb38934f55b329df36468daf2.png"
download_flag "holy_roman_empire" "https://static.aoe4world.com/assets/flags/holy_roman_empire-fc0be4151234fc9ac8f83e10c83b4befe79f22f7a8f6ec1ff03745d61adddb4c.png"
download_flag "rus" "https://static.aoe4world.com/assets/flags/rus-cb31fb6f8663187f63136cb2523422a07161c792de27852bdc37f0aa1b74911b.png"
download_flag "malians" "https://static.aoe4world.com/assets/flags/malians-edb6f54659da3f9d0c5c51692fd4b0b1619850be429d67dbe9c3a9d53ab17ddd.png"
download_flag "chinese" "https://static.aoe4world.com/assets/flags/chinese-2d4edb3d7fc7ab5e1e2df43bd644aba4d63992be5a2110ba3163a4907d0f3d4e.png"
download_flag "knights_templar" "https://static.aoe4world.com/assets/flags/knights_templar-0dc0979a16240ed364b6859ec9aef4cd53f059144ee45b6fd3ea7bfaea209b16.png"
download_flag "house_of_lancaster" "https://static.aoe4world.com/assets/flags/house_of_lancaster-4b590484b88bb49e122c8e7933913f35774fd4d2c5e1505fdc93b628da8b6174.png"

# Special handling for webp files - download as webp
echo "Downloading tughlaq_dynasty flag..."
curl -s -o "aoe4_flags/tughlaq_dynasty.webp" "https://www.ageofempires.com/wp-content/themes/ageOfEmpires/dist/images/civs/flags/age4-civ-flag-tug-64.webp"
echo "Downloading sengoku_daimyo flag..."
curl -s -o "aoe4_flags/sengoku_daimyo.webp" "https://www.ageofempires.com/wp-content/themes/ageOfEmpires/dist/images/civs/flags/age4-civ-flag-sen-64.webp"
echo "Downloading macedonian_dynasty flag..."
curl -s -o "aoe4_flags/macedonian_dynasty.webp" "https://www.ageofempires.com/wp-content/themes/ageOfEmpires/dist/images/civs/flags/age4-civ-flag-mac-64.webp"
echo "Downloading golden_horde flag..."
curl -s -o "aoe4_flags/golden_horde.webp" "https://www.ageofempires.com/wp-content/themes/ageOfEmpires/dist/images/civs/flags/age4-civ-flag-goh-64.webp"
curl -s -o "aoe4_flags/jin_dynasty.webp" "https://cdn.ageofempires.com/aoe/wp-content/uploads/2026/03/flag_jin-1080x608.webp"

echo "All flags have been downloaded to the 'aoe4_flags' directory."
