## Context

- Thermal display today is a hardcoded list of mock points drawn by `_FlightOverlayPainter` in `map_widget.dart` when `mapShowThermals` is true. Airspace, track and pilot marker are also Flutter `CustomPainter` overlays on top of the MapLibre view.
- MapLibre (`maplibre` 0.3.6) loads a style JSON built by `MapLibreMapService.buildStyleJson`. All local data is served by `LocalTileServer`, a loopback HTTP server with routes `/tiles/...pbf` and `/terrain/...png`. These resolve in this order: PMTiles archive, disk cache, online. Its disk cache lives in `getTemporaryDirectory()`, which the OS may purge.
- Regions live in `{appSupport}/regions/<id>/map.pmtiles`. There is no catalog or region manager yet (`offline-region-download-manager` is unimplemented). `PMTilesReader` already parses header bounds.
- KK7 serves 256 px PNG tiles in TMS orientation, native max zoom 12, at `https://thermal.kk7.ch/tiles/thermals_<season>_<time>/{z}/{x}/{y}.png?src=<host>`, with season in `all|jan|apr|jul|oct` and time in `all|04|07|10`. License is CC BY-NC-SA 4.0.
- Requirements: see `specs/kk7-thermal-heatmap-layer`, `specs/thermal-tile-prefetch`, `specs/offline-vector-map-rendering`.

## Goals / Non-Goals

**Goals:**
- One tile path (loopback server) for online, cached and prefetched thermal tiles, so MapLibre never talks to KK7 directly on mobile.
- Pure, unit-testable domain logic for variant selection (season, sunrise, time bin) and prefetch planning (tile enumeration, required variants).
- No new runtime dependencies.

**Non-Goals:**
- A full region manager UI. This change only adds a thermal-data section that the future region manager can embed.
- Web offline support. On web, the layer points directly at KK7 (`scheme: tms`) without cache or prefetch.

## Decisions

### D1. Serve thermals through `LocalTileServer` (`/thermals/<variant>/{z}/{x}/{y}.png`)
MapLibre requests XYZ tiles from the loopback server. The server converts to TMS (`y_tms = 2^z - 1 - y`) only when calling KK7. Lookup order: region store (all downloaded regions whose bounds contain the tile), persistent browse cache, KK7 online (5 s timeout), then a static 1x1 transparent PNG.
- *Alternative*: point MapLibre directly at KK7 and rely on MapLibre's ambient cache. Rejected because there's no control over persistence, no offline guarantee and no shared storage with prefetch.
- *Alternative*: pack prefetched tiles into a PMTiles archive per region. Rejected because writing PMTiles incrementally is complex, and resume or partial states are harder. Plain files are enough at about 10k tiles per region.

### D2. Storage layout
```
{appSupport}/regions/<id>/thermals/
    <season>_<time>/<z>/<x>/<y>.png      # XYZ addressing; 0-byte file = provider had no data
    state.json                           # per-variant: expected, stored, status, updatedAt
{appSupport}/thermal_cache/<season>_<time>/<z>/<x>/<y>.png   # browse cache, LRU-capped at 200 MB
```
Storing the tiles inside the region folder means region deletion and the future region manager's atomic swap handle thermal tiles automatically. Zero-byte markers prevent refetching empty or ocean tiles (HTTP 404 or 204). Writes go to `*.tmp` and are then renamed to stay crash-safe.
- *Alternative*: one global thermal store keyed by tile. Rejected because overlapping regions (about 20 km) would need reference counting on delete.

### D3. Rendering as a MapLibre raster layer, not a Flutter painter
Add a `RasterSource` (`tileSize: 256`, `maxZoom: 12`, so MapLibre overzooms past 12) and a `RasterStyleLayer` (`raster-opacity` from settings) in the style JSON, placed below the first label/symbol layer of `alpine_relief.json`. Flutter overlays (airspace, track, pilot) are drawn above the MapLibre view, so the required layer order follows automatically. When the variant or opacity changes at runtime, the layer and source are swapped through `StyleController.removeLayer/removeSource/addSource/addLayer`. The full style is not reloaded, which avoids a camera reset or flicker.
- *Alternative*: decode PNGs and paint in `CustomPainter`. Rejected because it duplicates tile math and costs UI-thread time and battery.

### D4. Variant selection as a pure domain function
`ThermalVariantResolver(date, localTime, position, seasonSetting, timeSetting) -> (season, time)`. Sunrise uses the NOAA solar position algorithm (pure Dart, ±1 min accuracy, standard 90.833° zenith). The map view model re-evaluates it every 60 s and on position jumps of more than 50 km, and emits only on change. That is cheap: one trigonometric evaluation per minute, off the telemetry hot path. Bins: morning < 6 h, midday 6 to < 9 h (per KK7's UI; the help text says 10 h), evening ≥ 9 h. Before sunrise maps to morning. Polar day or night maps to `all`. Position fallback: last fix, else map view center.

### D5. Prefetch planner and worker
- **Planner (pure)**: given a region bbox and date, it returns the required variants (current season × 4; plus next season × 4 when the month is Feb, May, Aug or Nov) and enumerates XYZ tiles for z0-12 that intersect the bbox. For an alps-east-sized region this is about 2.2k tiles per variant.
- **Worker**: `ThermalPrefetchService` runs in a background isolate-free async queue. Network I/O is non-blocking, and PNG bytes are written as-is without decoding. Limits: token bucket of 4 req/s, 2 concurrent requests, existing-file skip, and exponential backoff on 429/5xx/timeout (1 s up to 5 min, 6 attempts per tile, then the region is marked `partial`). Progress is exposed as a stream per region.
- **Triggers**: app start and resume, region added (filesystem scan now, region-manager hook later), the day the required-variant set changes, and manual retry. Connectivity is detected by trying the request (a failure means offline, so back off and retry on next resume or after 15 min). No connectivity plugin is added.
- **Pruning**: after all required variants reach `complete`, variant directories not in the required set are deleted. Old variants stay usable until then.
- *Alternative*: download whole variants via the KK7 KML/WMTS APIs. Rejected because no bulk export exists for the raster layer.

### D6. Settings model
Per map widget, in the `ui_config.dart` widget config: `mapShowThermals` (existing), `mapThermalSeason` (enum incl. `auto`), `mapThermalTimeOfDay` (enum incl. `auto`), `mapThermalOpacity` (0.1-1.0, default 0.6). Global setting: `UIConfig.thermalAutoPrefetch` (default true), persisted with the rest of the UI config. The config sheet groups them under "Thermal Updraft Hotspots". A "Thermal map data" panel in map settings lists local regions with prefetch state, size and a refresh/retry action.

### D7. Region bounds source
`RegionBoundsProvider` returns catalog bounds when available and otherwise reads them from the `map.pmtiles` header. This decouples the change from `offline-region-download-manager` while keeping it ready to integrate.

### D8. Keep MapLibre requesting tiles while the device is offline
MapLibre Android stops issuing tile requests when Android reports no connectivity, including requests to `127.0.0.1`. Since every map source is served by the loopback tile server, which already falls back to local data or a transparent tile, `MainActivity` calls `MapLibre.setConnected(true)` at startup. Found during the airplane-mode device check; it also fixes the existing offline base map and terrain.
- *Alternative*: register the loopback URLs as a MapLibre offline region or use `file://` sources. Rejected because PMTiles serving and the thermal fallback chain live in the tile server.

## Risks / Trade-offs

- [KK7 changes URL scheme, layer names or terms] → All provider constants live in one place. Failures degrade to a transparent layer. The governance entry gets a revalidation date and a note to contact the author.
- [Load on the volunteer-run KK7 server] → Rate limit, skip-existing, zero-byte markers and `src=brandyfly` for traceability. The author is informed about the expected load before release.
- [Tile coordinates reveal the areas a pilot downloads or views] → Same exposure as base map tiles. No position, identifiers or cookies are sent. This is documented in the governance doc.
- [Storage growth: about 55 MB per catalog-sized region (alps-east) and season set, measured from live KK7 tiles at about 6 KB per tile, double during transitions, plus a 200 MB browse cache] → Sizes are shown per region, the cache is LRU-capped, and region deletion cleans up.
- [Midday/evening boundary ambiguity (9 h vs 10 h)] → Use 9 h, matching KK7's UI. The constant is isolated and unit-tested.
- [Variant switch in flight causes a visual change] → The switch happens at most a few times per day, without a style reload. Pilots who don't want it can set a fixed variant manually.
- [Web has no offline thermal support] → Accepted. Web is not a flight target.

## Migration Plan

- Existing widget configs have no thermal season, time or opacity fields, so the effective defaults apply (`auto`, `auto`, 0.6). `mapShowThermals` keeps its meaning.
- Mock thermal code (`defaultMockThermalHotspots`, `_paintThermals`, related paints) is removed. Tests that assert mock dots are updated.
- Rollback: disabling `mapShowThermals` removes all thermal network activity for display. Turning `thermalAutoPrefetch` off stops automatic prefetch. Thermal directories can be deleted without affecting regions.

## Open Questions

- Resolved during implementation: KK7 answers empty or ocean tiles with HTTP 200 and a tiny (68-byte) image, which is stored as-is. 404/204 responses are still handled as zero-byte markers (D2).
- The exact attribution UI placement depends on the existing attribution control and can be settled during implementation within the spec's "visible or accessible" contract.
