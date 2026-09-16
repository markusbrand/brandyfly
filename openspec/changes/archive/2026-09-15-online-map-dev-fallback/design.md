## Context

See `proposal.md` for motivation. Currently, `LocalTileServer` binds to `127.0.0.1` on an ephemeral port and acts as the sole vector tile provider for MapLibre GL Native (`alpine_relief.json` style).

In the absence of a regional `map.pmtiles` archive, the server attempts to fall back to `https://tiles.openfreemap.org/planet/{z}/{x}/{y}.pbf`. However:
1. OpenFreeMap changed its raw tile URL structure to versioned snapshot paths (e.g. `/planet/20260906_080001_pt/{z}/{x}/{y}.pbf`), causing unversioned planet requests to return 0-byte dummy tiles.
2. Downloaded tiles are currently discarded immediately after streaming, preventing offline reuse.
3. iOS App Transport Security (ATS) defaults to blocking cleartext `http://` loopback connections from the native MapLibre engine.

## Goals / Non-Goals

**Goals:**
- Dynamically resolve the active OpenFreeMap vector snapshot URL with a robust static fallback.
- Persist proxied vector tiles to a local disk cache (`vector_tiles/{z}/{x}/{y}.pbf`) so viewed regions remain available offline.
- Enable cleartext loopback networking in iOS `Info.plist` without opening external cleartext vulnerabilities.
- Update `MapWidget` to visually distinguish between live online streaming and missing offline data.
- Guarantee sub-3s failure timeouts during flight disconnects with standard HTTP 204 responses.

**Non-Goals:**
- Online raster DEM hillshade streaming: deferred beyond MVP; hillshades remain flat when local `terrain.pmtiles` is missing.
- Heavy external database/cache dependencies (e.g., SQLite for tiles); standard file-system pathing is sufficient and lightweight.
- Bulk background area downloading (managed separately by `offline-region-download-manager`).

## Decisions

### 1. Dynamic Snapshot URL Discovery with Static Fallback
- **Choice**: During `LocalTileServer.start()`, dispatch an asynchronous non-blocking HTTP GET to `https://tiles.openfreemap.org/planet`. Extract the first URL template from `tiles: [...]`. If the request fails or times out (2.0s), fall back to a known-valid snapshot template (e.g., `https://tiles.openfreemap.org/planet/20260906_080001_pt/{z}/{x}/{y}.pbf`).
- **Rationale**: Keeps the app resilient to upstream OpenFreeMap snapshot rotations while ensuring startup is never delayed or blocked when offline.
- **Alternatives Considered**:
  - *Hardcoding snapshot timestamp*: Will break on future OpenFreeMap CDN deprecations.
  - *Proxying via third-party Mapbox/Maptiler APIs*: Requires API keys and egress billing.

### 2. Hierarchical Storage & Disk-Backed Tile Caching
- **Choice**: Store proxied `.pbf` tiles in the application cache directory (`${cacheDir}/vector_tiles/${z}/${x}/${y}.pbf`). Request resolution pipeline:
  1. Primary regional PMTiles (`map.pmtiles`) via `PMTilesReader`
  2. Overview PMTiles (`global_overview.pmtiles`) via `PMTilesReader`
  3. Disk cache file lookup (`vector_tiles/${z}/${x}/${y}.pbf`)
  4. Online proxy via `HttpClient` (write to disk cache on HTTP 200, then stream to MapLibre)
  5. Return HTTP 204 No Content
- **Rationale**: Minimal latency (< 1ms from disk cache), zero re-downloading of identical tiles, and natural disk management via the OS cache directory.
- **Alternatives Considered**:
  - *Memory-only cache*: Lost on every app restart; useless for offline development testing.
  - *SQLite BLOB cache*: Unnecessary locking and abstraction overhead for immutable static PBF blobs.

### 3. iOS App Transport Security (ATS) Policy
- **Choice**: Add `NSAllowsLocalNetworking: true` under `NSAppTransportSecurity` in `ios/Runner/Info.plist`.
- **Rationale**: `NSAllowsLocalNetworking` explicitly permits cleartext loopback (`127.0.0.1`, `localhost`) for local servers while retaining strict HTTPS enforcement for all public internet connections. Matches Android's `network_security_config.xml` configured in PR #169.
- **Alternatives Considered**:
  - *`NSAllowsArbitraryLoads: true`*: Insecure; allows arbitrary cleartext traffic everywhere and risks App Store review rejection.

### 4. Online Preview Status in MapWidget
- **Choice**: `LocalTileServer` notifies or provides state when online proxying is active. `MapLibreMapService` exposes `isOnlinePreviewActive`, prompting `MapWidget` to render:
  - `"Online preview (No offline data)"` in amber/teal when online fallback is actively serving.
  - `"No offline data (Overview fallback)"` in deep amber when disconnected with no cache.
- **Rationale**: Pilots are explicitly informed that they are viewing online or cached preview data and need to download an offline mountain region before flight.

## Risks / Trade-offs

- **[Risk] High Zoom Tile Requests Over Slow Cellular**: Panning rapidly over poor cell connections could queue many slow requests.
  - *Mitigation*: 3-second connection timeout, `noContent` on drop, and MapLibre's native tile request cancellation prevent starvation.
- **[Risk] Uncontrolled Cache Growth**: Browsing large map areas could accumulate disk space over months.
  - *Mitigation*: Store under `getTemporaryDirectory()` / cache directory, which the mobile OS automatically reclaims under storage pressure, and keep files directly accessible for manual cleanup.
