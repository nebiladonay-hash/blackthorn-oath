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

# CC0, AutoSprite: Silver Knight. Idle, walk_loop and sprint_loop clips.
download_asset "silver-knight.glb" \
  "https://pub-63ab27389d044634a73e89c1a0c6d4a6.r2.dev/free-library/3d-models/silver-knight/silver-knight.glb" \
  5000000

# CC0, AutoSprite: T1 Sentinel. Sword-and-shield boss silhouette, idle and walk_loop.
download_asset "t1-sentinel.glb" \
  "https://pub-63ab27389d044634a73e89c1a0c6d4a6.r2.dev/free-library/3d-models/t1-sentinel/t1-sentinel.glb" \
  15000000

# CC0, OpenGameArt RPG Sound Pack by artisticdude: sword swishes, hits,
# creature vocalizations, footsteps and UI/gameplay sounds.
SFX_DIR="audio/sfx"
mkdir -p "$SFX_DIR"
SFX_ARCHIVE="/tmp/blackthorn-rpg-sound-pack.zip"
if [[ ! -f "$SFX_DIR/.cc0-rpg-pack-installed" ]]; then
  echo "Downloading CC0 RPG sound effects ..."
  curl --fail --location --retry 4 --retry-delay 2 --connect-timeout 30 \
    "https://opengameart.org/sites/default/files/rpg_sound_pack.zip" \
    -o "$SFX_ARCHIVE"
  unzip -oq "$SFX_ARCHIVE" -d "$SFX_DIR"
  touch "$SFX_DIR/.cc0-rpg-pack-installed"
fi
echo "Available CC0 sound files:"
find "$SFX_DIR" -type f \( -iname '*.wav' -o -iname '*.ogg' -o -iname '*.mp3' \) -printf '%P\\n' | sort
