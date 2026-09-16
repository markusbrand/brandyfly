## Context

MapLibre Native is the sole map rendering engine in BrandyFly, consuming vector tiles and raster DEM tiles via `LocalTileServer` running on `127.0.0.1`. Currently, `alpine_relief.json` contains layer definitions using the Protomaps vector schema (`roads`, `pois`, `places`, `earth` with `kind` / `kind_detail` property filters), whereas OpenFreeMap and the repo's Planetiler pipeline generate OpenMapTiles v3 schema (`transportation`, `poi`, `place`, `mountain_peak`, `water`, `landcover`, `landuse` with `class` and `subclass`). Because only `peak-omt-points` matched without a filter, the map displayed hundreds of brown dots without background features. Additionally, `alpine_relief.json` lacked a `hillshade` layer, and `MapLibreMapService` stripped terrain sources whenever regional files were missing.

## Goals / Non-Goals

**Goals:**
- Provide full, authentic OpenMapTiles v3 rendering in `alpine_relief.json`: Alpine forests, meadows, bare rock, glaciers, water bodies, rivers, roads, hiking paths, aerialways, town labels, and clean mountain peak labels with elevation.
- Display visible hillshade relief across the Alps and worldwide in both offline flight (from local `terrain.pmtiles`) and development simulation (via loopback proxy and disk caching of AWS Terrarium DEM tiles).
- Keep all network requests routed through `LocalTileServer` on `127.0.0.1` so MapLibre Native does not encounter external networking quirks or bypass local disk caching.

**Non-Goals:**
- Downloading full multi-gigabyte regional archives in this change (delegated to `offline-region-download-manager`).
- Client-side CPU contour generation.

## Decisions

### 1. Style Architecture: OpenMapTiles v3 Specification
- **Choice**: Structure `alpine_relief.json` strictly against OpenMapTiles v3 layers:
  - `landcover` / `landuse`: `class in ('wood', 'forest')` -> `#d2e8cb`, `class in ('meadow', 'grass', 'scrub')` -> `#e2f0d9`, `class in ('rock', 'bare_rock', 'scree')` -> `#dedad5`, `class = 'glacier'` -> `#e8f4f8`.
  - `water` / `waterway`: `water` fill -> `#aad3df`, `waterway` lines (`class in ('river', 'stream', 'canal')`) -> `#9bcad6`.
  - `transportation`: Thin muted line hierarchy: major highways (`#d48834`), minor roads (`#ffffff` / `#cfcac2`), tracks and hiking paths (`#b34d28` dashed), and aerialways/lifts (`#2c2c2c` dashed).
  - `mountain_peak`: Replace the unconstrained circle overlay with a zoom-dependent symbol layer (`minzoom: 11`) rendering peak name and elevation in meters (`{name}\n{ele}m`), avoiding point clutter at lower zoom levels.
  - `place`: Town, village, and locality names zoom-dependent with legible white halos.
- **Alternatives Considered**: Retaining dual Protomaps and OpenMapTiles rules in a bloated JSON file was rejected; OpenMapTiles v3 is the canonical standard used by both our Planetiler offline pipeline and online open vector tile mirrors.

### 2. Hillshade Layer & Terrain Source in `alpine_relief.json`
- **Choice**: Add layer `hillshade` directly above `background` and below `landcover`:
  ```json
  {
    "id": "hillshade",
    "type": "hillshade",
    "source": "terrain",
    "paint": {
      "hillshade-illumination-direction": 315,
      "hillshade-exaggeration": 0.8,
      "hillshade-shadow-color": "#473b31",
      "hillshade-highlight-color": "#ffffff"
    }
  }
  ```
- **Rationale**: A 315° illumination (NW) is cartographic standard for Alpine relief. Exaggeration 0.8 provides crisp ridge separation without washing out valley vegetation colors.

### 3. LocalTileServer Terrain Endpoint (`/terrain/{z}/{x}/{y}.png`)
- **Choice**: Extend `LocalTileServer` to support a `/terrain/{z}/{x}/{y}.png` endpoint:
  1. Check primary `_terrainReader` (`terrain.pmtiles`).
  2. Check local disk cache (`/cache/terrain_tiles/{z}/{x}/{y}.png`).
  3. If missing and `onlineFallbackEnabled`, proxy from AWS Terrarium DEM (`https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png`) and cache to disk.
  4. If offline and absent, return HTTP 204 No Content.
- **Alternatives Considered**: Direct HTTPS connection from MapLibre to AWS Terrarium was rejected because it bypasses BrandyFly's offline disk cache and loopback network security configuration.

### 4. Style Compilation in `MapLibreMapService`
- **Choice**: In `buildStyleJson`, always configure the `terrain` source pointing to `${_tileServer.baseUrl}/terrain/{z}/{x}/{y}.png` with `tileSize: 256` and `encoding: "terrarium"`.
- **Rationale**: This allows MapLibre to seamlessly receive terrain tiles from either offline PMTiles or disk-cached loopback proxy without needing style re-compilation or removing the hillshade layer.

## Risks / Trade-offs

- [Risk] Online DEM fetching during initial development run could introduce slight latency on first load.
  → Mitigation: Tiles are cached permanently to disk in `/cache/terrain_tiles/`; subsequent viewings load instantaneously from disk without network access.
- [Risk] Low-zoom hillshade bandwidth in simulation.
  → Mitigation: Max zoom on terrain is clamped, requests time out in <= 3 seconds and return 204 when offline, preserving UI responsiveness.
