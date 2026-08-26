#!/usr/bin/env bash
# Validate data source governance records and package manifests against compliance rules.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Running BrandyFly data source governance validation..."
cargo run --manifest-path "$REPO_ROOT/packages/contracts/Cargo.toml" --bin validate_data_sources -- "$@"
