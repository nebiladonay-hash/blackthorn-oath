#!/usr/bin/env bash
set -euo pipefail

ASSET_DIR="assets/models"
ASSET_PATH="$ASSET_DIR/generic-gothic-cathedral.glb"
ASSET_URL="https://www.innerscene.com/api/library/generic-gothic-cathedral-89717f0f/download"

mkdir -p "$ASSET_DIR"
if [[ -s "$ASSET_PATH" ]]; then
  echo "Cathedral asset already present: $ASSET_PATH"
  exit 0
fi

echo "Downloading CC0 Gothic cathedral landmark..."
curl --fail --location --retry 4 --retry-delay 2 --connect-timeout 30 "$ASSET_URL" -o "$ASSET_PATH"
SIZE="$(wc -c < "$ASSET_PATH")"
if [[ "$SIZE" -lt 1000000 ]]; then
  echo "Downloaded cathedral asset is unexpectedly small ($SIZE bytes)." >&2
  rm -f "$ASSET_PATH"
  exit 1
fi
file "$ASSET_PATH"
sha256sum "$ASSET_PATH"
