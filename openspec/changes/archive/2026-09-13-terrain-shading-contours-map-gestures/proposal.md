## Why

The map widget renders flat OpenStreetMap vector tiles without any terrain elevation visualization. Pilots cannot assess mountain ridges, steep walls, valleys, or landing field slopes from the map alone. The existing `terrain` raster-dem source is defined in the style JSON and wired through `buildStyleJson()`, but no `hillshade` layer has ever been added to the style — the visual terrain relief described in the spec has never been implemented.

Separately, map panning is broken: a Flutter `GestureDetector` wrapping the `MapLibreMap` intercepts all touch events and shifts only the `CustomPaint` flight overlay via `_panOffset`, while the native MapLibre GL camera stays frozen. Pinch-to-zoom and two-finger rotate are also blocked. This makes the map unusable for manual navigation during flight planning or replay.

## What Changes

- **Add hillshade terrain layer** to `alpine_relief.json` style, rendering Copernicus DEM relief shading via MapLibre GL's native hillshade layer type. Activates automatically when `terrain.pmtiles` is present; degrades gracefully to flat rendering when absent.
- **Add contour line vector source and layers** for fine-grained elevation assessment. Contour lines at 10m (minzoom 14), 50m (minzoom 12), and 100m (minzoom 10, labeled with elevation). Served from a separate `contours.pmtiles` archive per region, toggleable via the existing `showContours` parameter.
- **Fix map gesture handling**: remove the wrapping `GestureDetector`, let MapLibre handle pan/pinch-zoom/rotate natively, and sync the `_FlightOverlayPainter` with the MapLibre camera via `onEvent: MapEventMoveCamera` and `controller.toScreenLocations()`. Preserve the 6-second auto-recenter timer using `CameraChangeReason.apiGesture` to distinguish user gestures from programmatic camera moves.
- **Update `maplibre_map_service.dart`** to detect and configure `contours.pmtiles` as an additional vector source when present in the region directory.
- **Extend the offline map data pipeline** with a contour generation step (`gdal_contour` → `tippecanoe` → `pmtiles convert`) producing `contours.pmtiles` per region alongside the existing `map.pmtiles` and `terrain.pmtiles`.

### Non-goals

- Hypsometric tinting / elevation-dependent color ramp — the existing landuse colors (forest green, glacier white, bare rock grey) provide a rough approximation. Deferred to a future change.
- Migrating flight overlays (track, airspace, thermals, pilot marker) from `CustomPaint` to native MapLibre layers — follow-up optimization after gesture sync is validated.
- 3D terrain extrusion rendering — outside scope.
- Online tile fallback for hillshade or contours when no regional archive is downloaded.

## Capabilities

### New Capabilities
- `contour-line-rendering`: Vector contour line display at 10m/50m/100m intervals from locally stored contour PMTiles archives, toggleable per map widget instance.

### Modified Capabilities
- `offline-vector-map-rendering`: Adds the missing hillshade layer to the Alpine Relief style. Adds map gesture handling requirements (native pan, pinch-zoom, rotate) and overlay camera synchronization. Adds contour source configuration in the style builder.

## Impact

- **Style**: `assets/map_styles/alpine_relief.json` — new hillshade layer, new contour source and layers.
- **Map widget**: `lib/widgets/flight/map_widget.dart` — remove `GestureDetector` wrapper, replace `_panOffset`-based projection with MapLibre camera-synced `toScreenLocations()`, wire `onEvent` for camera tracking.
- **Map service**: `lib/services/maplibre_map_service.dart` — detect and configure `contours.pmtiles` vector source in `buildStyleJson()`.
- **Pipeline**: `tools/map-pipeline/` — new contour generation step, updated region output structure.
- **Dependencies**: No new Flutter/Dart dependencies. Pipeline additions: `gdal_contour` (GDAL), `tippecanoe`, existing `pmtiles` CLI.
- **Offline**: All terrain and contour data is local-first. No change to offline safety guarantees.
- **Privacy**: No change — no new data collection or network requests.
- **Safety**: Improved — pilots gain terrain awareness from hillshade and contour visualization, and map interaction becomes reliable for in-flight use.
- **Licensing**: Contour data derived from Copernicus GLO-30 (CC-BY-4.0) — same attribution already required for terrain DEM.
