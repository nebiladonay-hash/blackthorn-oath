#!/usr/bin/env bash
set -euo pipefail

ASSET_DIR="assets/models"
mkdir -p "$ASSET_DIR"

download_asset() {
  local name="$1"
  local url="$2"
  local minimum_bytes="$3"
  local destination="$ASSET_DIR/$name"

  if [[ -s "$destination" ]]; then
    echo "Asset already present: $destination"
    return
  fi

  echo "Downloading $name ..."
  curl --fail --location --retry 4 --retry-delay 2 --connect-timeout 30 "$url" -o "$destination"
  local size
  size="$(wc -c < "$destination")"
  if [[ "$size" -lt "$minimum_bytes" ]]; then
    echo "Downloaded $name is unexpectedly small ($size bytes)." >&2
    rm -f "$destination"
    return 1
  fi
  file "$destination"
  sha256sum "$destination"
}

# CC0, Innerscene Free Parts Library: Generic gothic cathedral.
download_asset "generic-gothic-cathedral.glb" \
  "https://www.innerscene.com/api/library/generic-gothic-cathedral-89717f0f/download" \
  10000000

# KayKit Adventurers: Knight (CC0). Official KayKit GitHub distribution.
download_asset "silver-knight.glb" \
  "https://raw.githubusercontent.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0/main/addons/kaykit_character_pack_adventures/Characters/gltf/Knight.glb" \
  3000000

# KayKit Dungeon Remastered (CC0): lightweight GLB props, downloaded from the
# creator's official repository. GLBs are self-contained and mobile-friendly.
KAYKIT_DIR="assets/kaykit_dungeon"
mkdir -p "$KAYKIT_DIR"
KAYKIT_BASE="https://raw.githubusercontent.com/KayKit-Game-Assets/KayKit-Dungeon-Remastered-1.0/main/addons/kaykit_dungeon_remastered/Assets/gltf"
for asset in torch_lit.gltf.glb torch_mounted.gltf.glb barrel_large_decorated.gltf.glb chest_gold.glb pillar_decorated.gltf.glb column.gltf.glb; do
  if [[ ! -s "$KAYKIT_DIR/$asset" ]]; then
    curl --fail --location --retry 4 --retry-delay 2 --connect-timeout 30 "$KAYKIT_BASE/$asset" -o "$KAYKIT_DIR/$asset"
  fi
done
curl --fail --location --retry 4 --retry-delay 2 --connect-timeout 30 \
  "https://raw.githubusercontent.com/KayKit-Game-Assets/KayKit-Dungeon-Remastered-1.0/main/LICENSE.txt" \
  -o "$KAYKIT_DIR/LICENSE.txt"
curl --fail --location --retry 4 --retry-delay 2 --connect-timeout 30 \
  "https://raw.githubusercontent.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0/main/LICENSE.txt" \
  -o "assets/models/KAYKIT-ADVENTURERS-LICENSE.txt"

# CC0, AutoSprite: T1 Sentinel. Sword-and-shield boss silhouette, idle and walk_loop.
download_asset "t1-sentinel.glb" \
  "https://pub-63ab27389d044634a73e89c1a0c6d4a6.r2.dev/free-library/3d-models/t1-sentinel/t1-sentinel.glb" \
  15000000

# Curated sound design: every file has a known purpose; no random category scraping.
SFX_DIR="audio/sfx/curated"
mkdir -p "$SFX_DIR"
curl --fail --location --retry 4 --retry-delay 2 --connect-timeout 30 \
  "https://static.3dvalley.com/kn/impact-sounds.footstep_concrete_000/footstep_concrete_000.ogg" \
  -o "$SFX_DIR/stone_step_01.ogg"
curl --fail --location --retry 4 --retry-delay 2 --connect-timeout 30 \
  "https://static.3dvalley.com/kn/impact-sounds.footstep_concrete_001/footstep_concrete_001.ogg" \
  -o "$SFX_DIR/stone_step_02.ogg"
curl --fail --location --retry 4 --retry-delay 2 --connect-timeout 30 \
  "https://static.3dvalley.com/kn/impact-sounds.impactMetal_heavy_000/impactMetal_heavy_000.ogg" \
  -o "$SFX_DIR/steel_impact_01.ogg"
curl --fail --location --retry 4 --retry-delay 2 --connect-timeout 30 \
  "https://static.3dvalley.com/kn/impact-sounds.impactMetal_heavy_001/impactMetal_heavy_001.ogg" \
  -o "$SFX_DIR/steel_impact_02.ogg"

SWISH_ARCHIVE="/tmp/blackthorn-swishes-cc0.zip"
SWISH_DIR="/tmp/blackthorn-swishes"
mkdir -p "$SWISH_DIR"
curl --fail --location --retry 4 --retry-delay 2 --connect-timeout 30 \
  "https://opengameart.org/sites/default/files/swishes.zip" -o "$SWISH_ARCHIVE"
unzip -oq "$SWISH_ARCHIVE" -d "$SWISH_DIR"
mapfile -t SWISH_FILES < <(find "$SWISH_DIR" -type f -iname '*.wav' | sort)
if [[ "${#SWISH_FILES[@]}" -lt 8 ]]; then
  echo "Expected 8 or more CC0 weapon swishes, found ${#SWISH_FILES[@]}" >&2
  exit 1
fi
for index in {0..7}; do
  printf -v output_name "sword_swing_%02d.wav" "$((index + 1))"
  cp "${SWISH_FILES[$index]}" "$SFX_DIR/$output_name"
done

# Cinzel display typeface, SIL Open Font License 1.1.
FONT_DIR="assets/fonts"
mkdir -p "$FONT_DIR"
curl --fail --location --retry 4 --retry-delay 2 --connect-timeout 30 \
  "https://raw.githubusercontent.com/google/fonts/main/ofl/cinzel/Cinzel%5Bwght%5D.ttf" \
  -o "$FONT_DIR/Cinzel.ttf"
curl --fail --location --retry 4 --retry-delay 2 --connect-timeout 30 \
  "https://raw.githubusercontent.com/google/fonts/main/ofl/cinzel/OFL.txt" \
  -o "$FONT_DIR/OFL-Cinzel.txt"

# Godot 4.4 boot splash only supports PNG. Render our custom SVG splash to PNG.
if ! command -v rsvg-convert >/dev/null 2>&1; then
  sudo apt-get update
  sudo apt-get install -y librsvg2-bin
fi
rsvg-convert --width 1600 --height 900 assets/ui/blackthorn_splash.svg -o assets/ui/blackthorn_splash.png

echo "Curated audio files:"
find "$SFX_DIR" -maxdepth 1 -type f -printf '%f\\n' | sort
