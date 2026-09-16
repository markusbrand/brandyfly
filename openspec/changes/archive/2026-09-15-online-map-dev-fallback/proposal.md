## Why

Following the migration to MapLibre GL and PMTiles, the map engine requires local regional `.pmtiles` archives to render vector features. On freshly launched devices, simulators, and in real app environments where regional maps have not yet been downloaded, the bundled overview archive is a minimal stub, resulting in a blank map canvas. In addition, the existing development proxy endpoint in `LocalTileServer` returns empty tiles due to upstream OpenFreeMap URL changes, and iOS App Transport Security restricts cleartext HTTP loopback requests.

An automated, transparent online vector fallback with local disk caching ensures developers, testers, and pilots immediately see rendered OpenStreetMap vector maps when offline data is absent, while strictly preserving zero-network flight safety once offline data is installed.

## What Changes

- **Active OpenFreeMap Snapshot Resolution**: Update `LocalTileServer` to dynamically resolve or point to active OpenFreeMap vector tile snapshots (OpenMapTiles schema matching `alpine_relief.json`), ensuring online requests return valid vector tile payloads instead of empty 0-byte responses.
- **Disk-Backed Tile Caching**: Persist downloaded online vector tiles to the app's local cache directory (`/cache/vector_tiles/{z}/{x}/{y}.pbf`), ensuring tiles are fetched once and remain available offline for recently browsed areas.
- **iOS App Transport Security (ATS) Configuration**: Add `NSAllowsLocalNetworking: true` under `NSAppTransportSecurity` in `ios/Runner/Info.plist` to permit cleartext loopback streaming to `127.0.0.1` on iOS simulators and physical devices.
- **Visual Status Badge Enhancement**: Update the map header fallback indicator in `MapWidget` to distinguish between pure offline overview fallback (`No offline data`) and live streaming fallback (`Online preview (No offline data)`).
- **Graceful Offline Timeout**: Ensure online proxy attempts fail quickly (<= 3s timeout) and return `204 No Content` when offline in flight, avoiding main-thread lockups or battery drain.

### Non-Goals

- **Online Hillshade / DEM Raster Fallback**: Online raster-dem streaming for terrain hillshade is deferred beyond MVP to keep network and memory consumption lean; flat background tint remains active in fallback mode.
- **Bulk Tile Pre-Downloading**: Online fallback is on-demand viewport streaming only; complete regional package management belongs to `offline-region-download-manager`.
- **Modifying Offline Priority**: Local regional PMTiles archives retain 100% priority whenever present.

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `offline-vector-map-rendering`: Update fallback behavior so that when local PMTiles are absent, the map proxies and caches online vector tiles from open endpoints in both development and real app modes, updates the UI badge to indicate online preview status, and supports iOS loopback transport.

## Impact

- **Affected Code**:
  - `apps/mobile/lib/services/local_tile_server.dart`: Upstream snapshot resolution, disk caching of vector tiles.
  - `apps/mobile/lib/widgets/flight/map_widget.dart`: Badge state reflecting online preview vs. missing data.
  - `apps/mobile/ios/Runner/Info.plist`: ATS local networking permissions.
  - `apps/mobile/test/services/local_tile_server_test.dart`: Tests for online proxying, caching, and fallback logic.
- **Dependencies**: No new third-party dependencies required; uses standard `dart:io` and `path_provider`.
- **Flight Safety & Offline Guarantee**: If offline data is installed, zero network traffic is emitted. If in flight without offline data and disconnected from cellular/Wi-Fi, queries fail fast without crashing or disrupting telemetry instruments.
