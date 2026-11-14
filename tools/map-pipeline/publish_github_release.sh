#!/usr/bin/env bash
# Publishes generated regional PMTiles archives, overview.pmtiles, catalog.json,
# and checksums.sha256 to the maps-v1 GitHub Release with flat asset names.
set -euo pipefail

OUTPUT_DIR="${1:-./output}"
RELEASE_TAG="${2:-maps-v1}"
REPO="${GITHUB_REPOSITORY:-markusbrand/brandyfly}"

if [ ! -d "$OUTPUT_DIR" ]; then
  echo "Error: Output directory '$OUTPUT_DIR' does not exist." >&2
  exit 1
fi

STAGE_DIR="$(mktemp -d)"
trap 'rm -rf "$STAGE_DIR"' EXIT

ASSETS=()

if [ -f "$OUTPUT_DIR/catalog.json" ]; then
  cp "$OUTPUT_DIR/catalog.json" "$STAGE_DIR/catalog.json"
  ASSETS+=("$STAGE_DIR/catalog.json")
fi

if [ -f "$OUTPUT_DIR/checksums.sha256" ]; then
  cp "$OUTPUT_DIR/checksums.sha256" "$STAGE_DIR/checksums.sha256"
  ASSETS+=("$STAGE_DIR/checksums.sha256")
fi

if [ -f "$OUTPUT_DIR/fallback/overview.pmtiles" ]; then
  cp "$OUTPUT_DIR/fallback/overview.pmtiles" "$STAGE_DIR/overview.pmtiles"
  ASSETS+=("$STAGE_DIR/overview.pmtiles")
fi

if [ -d "$OUTPUT_DIR/regions" ]; then
  for region_dir in "$OUTPUT_DIR/regions"/*; do
    [ -d "$region_dir" ] || continue
    region_id="$(basename "$region_dir")"
    if [ -f "$region_dir/map.pmtiles" ]; then
      cp "$region_dir/map.pmtiles" "$STAGE_DIR/${region_id}-map.pmtiles"
      ASSETS+=("$STAGE_DIR/${region_id}-map.pmtiles")
    fi
    if [ -f "$region_dir/terrain.pmtiles" ]; then
      cp "$region_dir/terrain.pmtiles" "$STAGE_DIR/${region_id}-terrain.pmtiles"
      ASSETS+=("$STAGE_DIR/${region_id}-terrain.pmtiles")
    fi
  done
fi

if [ "${#ASSETS[@]}" -eq 0 ]; then
  echo "Error: No map assets found in '$OUTPUT_DIR' to publish." >&2
  exit 1
fi

echo "Ensuring GitHub Release '$RELEASE_TAG' exists on '$REPO'..."
if ! gh release view "$RELEASE_TAG" --repo "$REPO" >/dev/null 2>&1; then
  gh release create "$RELEASE_TAG" \
    --repo "$REPO" \
    --title "BrandyFly Offline Map Regions ($RELEASE_TAG)" \
    --notes "Automated offline vector map (OpenMapTiles PMTiles v3) and terrain DEM (Copernicus GLO-30 Terrarium PNG PMTiles v3) archives for BrandyFly."
fi

echo "Uploading ${#ASSETS[@]} asset(s) to GitHub Release '$RELEASE_TAG'..."
gh release upload "$RELEASE_TAG" "${ASSETS[@]}" --repo "$REPO" --clobber
echo "Successfully published map assets to https://github.com/$REPO/releases/tag/$RELEASE_TAG"
