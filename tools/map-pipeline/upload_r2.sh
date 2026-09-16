#!/usr/bin/env bash
# ==============================================================================
# BrandyFly Offline Map Pipeline - Cloudflare R2 Upload Script
# ==============================================================================
# Uploads generated PMTiles files and catalog.json to Cloudflare R2 bucket.
# Requires environment variables:
#   R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_BUCKET_NAME
# Optional:
#   R2_CUSTOM_DOMAIN (e.g. cdn.brandyfly.org)
# ==============================================================================

set -euo pipefail

OUTPUT_DIR="${1:-./output}"
BUCKET_NAME="${R2_BUCKET_NAME:-brandyfly-maps}"

if [ ! -d "$OUTPUT_DIR" ]; then
  echo "Error: Output directory does not exist: $OUTPUT_DIR" >&2
  exit 1
fi

if [ ! -f "$OUTPUT_DIR/catalog.json" ]; then
  echo "Error: catalog.json not found in $OUTPUT_DIR" >&2
  exit 1
fi

if [ -z "${R2_ACCESS_KEY_ID:-}" ] || [ -z "${R2_SECRET_ACCESS_KEY:-}" ] || [ -z "${R2_ACCOUNT_ID:-}" ]; then
  echo "Notice: R2 credentials not fully set in environment (dry-run mode)."
  echo "Would upload from: $OUTPUT_DIR to bucket: $BUCKET_NAME"
  exit 0
fi

# Configure rclone via environment
export RCLONE_CONFIG_R2_TYPE="s3"
export RCLONE_CONFIG_R2_PROVIDER="Cloudflare"
export RCLONE_CONFIG_R2_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID"
export RCLONE_CONFIG_R2_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY"
export RCLONE_CONFIG_R2_ENDPOINT="https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com"

echo "=== Uploading PMTiles archives to R2 (immutable, long cache) ==="
rclone copy "$OUTPUT_DIR" "r2:${BUCKET_NAME}" \
  --include "*.pmtiles" \
  --header-upload "Cache-Control: public, max-age=2592000, immutable" \
  --header-upload "Content-Type: application/vnd.pmtiles" \
  --checksum \
  --transfers 4 \
  --progress

echo "=== Uploading catalog.json and checksums (short cache) ==="
rclone copy "$OUTPUT_DIR" "r2:${BUCKET_NAME}" \
  --include "catalog.json" \
  --include "*.sha256" \
  --header-upload "Cache-Control: public, max-age=300, must-revalidate" \
  --header-upload "Content-Type: application/json" \
  --transfers 2 \
  --progress

echo "Upload to R2 bucket '${BUCKET_NAME}' completed successfully."
