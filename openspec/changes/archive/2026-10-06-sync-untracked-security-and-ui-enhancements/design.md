## Context

To ensure complete spec-to-code traceability, changes performed across commits #214, #230, and #239 are formalized into the OpenSpec repository specifications.

## Architecture Decisions

### 1. Loopback Tile Server CORS Protection (`apps/mobile`)
- The embedded loopback HTTP tile server (`LocalTileServer`) operates exclusively on `127.0.0.1` to serve MapLibre Native and internal cache lookups.
- Native mobile components do not require Cross-Origin Resource Sharing (CORS) headers.
- Emitting wildcard `Access-Control-Allow-Origin: *` headers allows unauthorized scripts executing in local web browsers or webviews to access loopback endpoints if the ephemeral port is scanned.
- Decision: Omit `Access-Control-Allow-Origin` headers entirely from local server responses.

### 2. Map Pipeline SSRF Prevention (`tools/map-pipeline`)
- Source extract downloads in `download_osm.py` take input URLs specified in configuration files.
- Without validation, arbitrary URLs could probe internal services or unintended remote hosts.
- Decision: Strictly require URLs to start with `https://download.geofabrik.de/`, raising a `ValueError` if untrusted schemes or hostnames are supplied.

### 3. Slender Slot Vertical Edge Bar Rendering (`apps/mobile`)
- Instrument widgets map dimensions into content tiers: `regular`, `compact`, and `tiny` (shortest side < 40 dp).
- Slender slots placed along screen edges (e.g. width = 1 cell, height = full screen) have a shortest dimension < 40 dp, classifying them as `SizeTier.tiny`.
- While numeric widgets show only digits in tiny mode, a vertical edge bar (`LiftSinkBarStyle.verticalEdgeBar`) is designed specifically for slender full-height edges.
- Falling back to `_buildTiny()` caused the bar to collapse into a tiny numeric pill, losing the continuous vertical lift/sink visual indicator.
- Decision: Exclude `LiftSinkBarStyle.verticalEdgeBar` from `_buildTiny()` so it continuously renders its vertical bar graphic.

## Verification Plan

- Unit test in `apps/mobile/test/services/local_tile_server_test.dart` verifying omission of wildcard CORS headers.
- Unit test in `tools/map-pipeline/test_pipeline.py` verifying rejection of untrusted URLs in `download_file`.
- Widget test in `apps/mobile/test/instrument_widgets_test.dart` verifying `VarioLiftSinkBar` with `verticalEdgeBar` style renders the edge bar graphic when `tier == SizeTier.tiny`.
