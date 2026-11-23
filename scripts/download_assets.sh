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

# Curated CC0 combat and ambience sound design from 3DValley.
SFX_DIR="audio/sfx/curated"
mkdir -p "$SFX_DIR"
download_sfx() {
  local url="$1"
  local output="$2"
  curl --fail --location --retry 4 --retry-delay 2 --connect-timeout 30 "$url" -o "$output"
  local size
  size=$(stat -c%s "$output")
  if [[ "$size" -lt 1024 ]]; then
    echo "Invalid or empty audio asset: $output ($size bytes)" >&2
    exit 1
  fi
  local signature
  signature=$(head -c 4 "$output")
  if [[ "$output" == *.ogg && "$signature" != "OggS" ]]; then
    echo "Invalid OGG header: $output" >&2
    exit 1
  fi
}
download_sfx "https://static.3dvalley.com/kn/impact-sounds.footstep_concrete_000/footstep_concrete_000.ogg" "$SFX_DIR/stone_step_01.ogg"
download_sfx "https://static.3dvalley.com/kn/impact-sounds.footstep_concrete_001/footstep_concrete_001.ogg" "$SFX_DIR/stone_step_02.ogg"
download_sfx "https://static.3dvalley.com/kn/impact-sounds.impactMetal_heavy_000/impactMetal_heavy_000.ogg" "$SFX_DIR/steel_impact_01.ogg"
download_sfx "https://static.3dvalley.com/kn/impact-sounds.impactMetal_heavy_001/impactMetal_heavy_001.ogg" "$SFX_DIR/steel_impact_02.ogg"
download_sfx "https://static.3dvalley.com/rd/rd-rpg-sfx.blade_01/blade_01.ogg" "$SFX_DIR/sword_swing_01.ogg"
download_sfx "https://static.3dvalley.com/rd/rd-rpg-sfx.blade_02/blade_02.ogg" "$SFX_DIR/sword_swing_02.ogg"
download_sfx "https://static.3dvalley.com/rd/rd-rpg-sfx.blade_03/blade_03.ogg" "$SFX_DIR/sword_swing_03.ogg"
download_sfx "https://static.3dvalley.com/rd/rd-creature-2.roar_05/roar_05.ogg" "$SFX_DIR/creature_roar_01.ogg"
download_sfx "https://static.3dvalley.com/rd/rd-creature-2.roar_04/roar_04.ogg" "$SFX_DIR/creature_roar_02.ogg"
download_sfx "https://static.3dvalley.com/rd/rd-rpg-sfx.creature_monster_01/creature_monster_01.ogg" "$SFX_DIR/creature_grunt_01.ogg"
download_sfx "https://static.3dvalley.com/rd/rd-rpg-sfx.creature_roar_03/creature_roar_03.ogg" "$SFX_DIR/creature_roar_03.ogg"

# Cinzel display typeface, SIL Open Font License 1.1.
FONT_DIR="assets/fonts"
mkdir -p "$FONT_DIR"
curl --fail --location --retry 4 --retry-delay 2 --connect-timeout 30 \
  "https://raw.githubusercontent.com/google/fonts/main/ofl/cinzel/Cinzel%5Bwght%5D.ttf" \
  -o "$FONT_DIR/Cinzel.ttf"
curl --fail --location --retry 4 --retry-delay 2 --connect-timeout 30 \
  "https://raw.githubusercontent.com/google/fonts/main/ofl/cinzel/OFL.txt" \
  -o "$FONT_DIR/OFL-Cinzel.txt"

# Godot 4.4 boot splash is raster-only. Render the custom SVG to PNG for startup.
if ! command -v rsvg-convert >/dev/null 2>&1; then
  sudo apt-get update
  sudo apt-get install -y librsvg2-bin
fi
rsvg-convert --width 1600 --height 900 assets/ui/blackthorn_splash.svg -o assets/ui/blackthorn_splash.png

echo "Validated curated audio files:"
find "$SFX_DIR" -maxdepth 1 -type f -printf '%f\\n' | sort
