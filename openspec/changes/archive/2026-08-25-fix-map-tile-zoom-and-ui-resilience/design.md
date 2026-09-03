# Design: Map Tile Zoom Fix and UI Hardening

## Context
See `proposal.md` for motivation. The paragliding app uses `flutter_map` (v8) with multiple raster tile styles (`MapWidgetStyle`: Topo Contours, Vector HUD, Thermal Radar, Shaded Relief). When `TileLayer.maxZoom` was set to the server's zoom limit (17.0 for OpenTopoMap), any camera zoom > 17.0 triggered flutter_map's layer cutoff, making the map disappear completely.

## Goals / Non-Goals

**Goals:**
- Separate tile server limits (`maxNativeZoom`) from layer visibility bounds (`maxZoom: 22.0`).
- Ensure tile layers smoothly upscale and overzoom when zoomed close to terrain or thermals.
- Guarantee clean recreation of `TileLayer` on style changes via explicit keys.
- Preserve pilot coordinate tracking and smooth orientation synchronization without jitter or unexpected zoom drops during telemetry streaming.

**Non-Goals:**
- Vector tile (MapLibre/MVT) offline vector engine replacement in this PR.

## Decisions

### Decision 1: Use `maxNativeZoom` and unbounded `maxZoom` in `TileLayer`
- **Choice**:
  ```dart
  TileLayer(
    key: ValueKey('tile_layer_${widget.style.name}_${tileConfig.label}'),
    urlTemplate: tileConfig.urlTemplate,
    fallbackUrl: tileConfig.fallbackUrl,
    subdomains: tileConfig.subdomains,
    maxNativeZoom: tileConfig.maxZoom.toInt(),
    minNativeZoom: tileConfig.minZoom.toInt(),
    maxZoom: 22.0,
    minZoom: 1.0,
    tileProvider: BrandyFlyTileProvider(...),
    ...
  )
  ```
- **Rationale**: `flutter_map` uses `maxNativeZoom` to cap HTTP tile requests at the actual maximum zoom level provided by the server (e.g. 17 for OpenTopoMap, 19 for OSM), while `maxZoom` determines when the layer is hidden. Setting `maxZoom: 22.0` allows the pilot to zoom in arbitrarily close, and `flutter_map` automatically bilinearly interpolates/scales the level 17 tiles.
- **Alternatives Considered**:
  - *Clamping map camera zoom to 17.0*: Rejected because pilots need to zoom in closely when centering on a thermal core or landing field.

### Decision 2: Distinct Key for `TileLayer`
- **Choice**: Attach `key: ValueKey('tile_layer_${widget.style.name}')` to `TileLayer`.
- **Rationale**: Forces Flutter to dispose and recreate the `TileLayerState` whenever the user changes the map style in the Edit Mode dialog, preventing tile cache leakage across styles.

### Decision 3: Telemetry DidUpdateWidget Camera Move Guarding
- **Choice**: Only trigger camera `_mapController.move` when `initialZoom` specifically changes from user configuration actions, and preserve the active user gesture zoom during flight telemetry stream updates.

## Risks / Trade-offs

- **[Risk] Pixelation on deep over-zoom**: High zoom (e.g., zoom 19 on zoom 17 tiles) will appear slightly soft or pixelated.
  - *Mitigation*: Bilinear filtering in Flutter canvas ensures tiles remain legible without jagged artifacts, which is vastly superior to a blank screen.
- **[Risk] OpenTopoMap rate limits**: OpenTopoMap tile server may intermittently fail under high concurrency.
  - *Mitigation*: Existing `BrandyFlyTileCacheService` caches tiles to disk, and `fallbackUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'` automatically fills in missing tiles from OSM.
