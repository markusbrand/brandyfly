## Context

The MapLibre GL migration is complete — vector tiles render from local PMTiles via a loopback HTTP tile server. See proposal.md for the three gaps being addressed: missing hillshade layer, broken gesture handling, and absent contour lines. The existing `alpine_relief.json` style defines a `terrain` raster-dem source but never references it in a layer. The `buildStyleJson()` service correctly strips this source when no DEM file is present.

For the gesture problem, the `MapLibreMap` widget is wrapped in a Flutter `GestureDetector` (map_widget.dart L258-269) that captures all pan events and applies them as pixel offsets to a `CustomPaint` overlay — the native GL camera never moves. The `maplibre 0.3.6` package exposes `MapGestures.all()`, `MapEventMoveCamera`, `MapController.toScreenLocations()`, and `CameraChangeReason.apiGesture`, providing everything needed for proper camera-synced overlays.

## Goals / Non-Goals

**Goals:**
- Native GPU-rendered hillshade terrain relief when DEM data is present
- Responsive, smooth native map gestures (pan, pinch-zoom, rotate)
- Flight overlays that stay geo-locked to the map during all interactions
- Toggleable contour line display at 10m/50m/100m intervals from separate vector archive
- Lowest possible latency on the overlay repaint path

**Non-Goals:**
- Hypsometric elevation color ramp (deferred — existing landuse colors approximate this)
- Migrating flight overlays from `CustomPaint` to native MapLibre GeoJSON/symbol layers (follow-up)
- 3D terrain extrusion
- Online tile fallback for hillshade or contours

## Decisions

### 1. Hillshade via MapLibre style layer (not custom shader)

**Chosen**: Add a `hillshade` layer in `alpine_relief.json` referencing the existing `terrain` raster-dem source. MapLibre renders it natively on the GPU.

**Alternatives considered**:
- *Custom Flutter shader/canvas painting from DEM data*: Would require reading DEM tiles on the Dart side, decoding terrain-RGB, computing normals — expensive, duplicates what MapLibre already does natively. Higher latency, higher battery drain.
- *Raster hillshade tile layer (pre-rendered server-side)*: Extra data to store/download, can't adjust illumination direction or exaggeration dynamically. Larger archive sizes per region.

**Rationale**: MapLibre's native hillshade rendering runs entirely on the GPU with configurable illumination. Zero Dart-side computation, zero additional data beyond the existing `terrain.pmtiles`. The style layer is stripped by `buildStyleJson()` when no DEM is available — graceful degradation is already handled.

**Hillshade paint configuration**:
- `hillshade-illumination-direction: 315` (NW, standard cartographic convention)
- `hillshade-exaggeration: 0.5` (moderate — avoids overpowering the vector overlays while still making ridges/valleys clearly visible)
- `hillshade-shadow-color: #3d4659` (cool slate grey — blends with the Alpine Relief palette)
- `hillshade-highlight-color: #ffffff` (white — exposed faces)
- `hillshade-accent-color: #5a7a4a` (muted green — accent on slopes facing the light)

Layer position: immediately after `background`, before all landuse/land cover layers. This places relief shading beneath forests, meadows, water — terrain visible through semi-transparent fill layers.

### 2. Gesture delegation to MapLibre native (not dual gesture system)

**Chosen**: Remove the `GestureDetector` wrapping `MapLibreMap`. Let MapLibre handle all pan/zoom/rotate gestures natively. Sync overlays via `onEvent` camera callbacks.

**Alternatives considered**:
- *Keep GestureDetector but forward events to MapLibre*: Complex, fragile — would need to convert pixel deltas to geo-coordinate deltas, handle inertia, match the native gesture recognizer's scroll physics. Duplicates work MapLibre already does.
- *Use MapLibre's `gestureRecognizers` parameter*: This is for resolving gesture arena conflicts (e.g., map inside a `ListView`), not for custom gesture handling. Not applicable here.

**Rationale**: MapLibre's native gesture handling provides smooth 60fps pan/zoom/rotate with platform-native physics (inertia, fling, snap). No Dart-side gesture processing overhead. The `GestureDetector` was only needed when flutter_map was the engine; with MapLibre GL, it is the bug.

**Camera sync design**:

```
MapLibre native gesture --> Camera moves (GPU, 60fps)
         |
         v
onEvent(MapEventMoveCamera(camera))
         |
         v
setState(() { _mapCamera = camera; })
         |
         v
_FlightOverlayPainter.paint():
  for each geo-point:
    screenPos = controller.toScreenLocations([...])  // batch call
  paint track, airspace, thermals, pilot at screen positions
```

`controller.toScreenLocations()` is a synchronous native bridge call — it executes the same mercator projection the GL renderer uses, so overlay positions are pixel-perfect with the map. Batch conversion for the flight track (typically 60-300 points for 10 min history) keeps the per-frame overhead under 1ms.

**Recenter logic**:
- `MapEventStartMoveCamera(reason: apiGesture)` → user is panning → set `_centerOnPilot = false`, start 6-second `Timer`
- `MapEventStartMoveCamera(reason: developerAnimation)` → programmatic move → no timer change
- Timer fires → `controller.animateCamera(center: pilotPosition, nativeDuration: 500ms)` → set `_centerOnPilot = true`
- When `_centerOnPilot == true` and pilot position updates → `controller.moveCamera(center: pilotPosition)`

### 3. Contour data as separate `contours.pmtiles` (not baked into `map.pmtiles`)

**Chosen**: Separate vector archive per region, served from the same loopback tile server as the map tiles, on a different source name.

**Alternatives considered**:
- *Baked into `map.pmtiles`*: Simpler pipeline, one file. But: can't toggle contours without reloading the entire map style; increases base map download size even for pilots who don't want contours; can't update contour data independently.
- *On-device contour generation from DEM*: Compute contours from `terrain.pmtiles` at runtime. No extra download. But: `gdal_contour` equivalent in Dart/Rust is expensive; startup latency; battery drain on first load. Not viable for a local-first safety-critical app.

**Rationale**: Separate archive enables: independent toggle via MapLibre layer visibility, independent update without re-downloading map tiles, smaller mandatory download (map + terrain), optional contour download for pilots who want it.

**Tile server routing**: The `LocalTileServer` needs a second route for contour tiles. Current architecture serves one primary + one fallback archive. Extend with a named-source dispatch:
- `/tiles/{z}/{x}/{y}.pbf` → primary map archive (existing)
- `/contours/{z}/{x}/{y}.pbf` → contour archive (new)

**Style source configuration** in `buildStyleJson()`:
```json
{
  "contours": {
    "type": "vector",
    "tiles": ["http://127.0.0.1:<port>/contours/{z}/{x}/{y}.pbf"]
  }
}
```

**Style layers** (inserted after roads, before labels):
| Layer ID | Interval | minzoom | Stroke | Width | Labels |
|---|---|---|---|---|---|
| `contour-100m` | 100m | 10 | `#8b6c42` 0.6 opacity | 1.4px | Yes (elevation in m) |
| `contour-50m` | 50m | 12 | `#8b6c42` 0.35 opacity | 0.9px | No |
| `contour-10m` | 10m | 14 | `#8b6c42` 0.2 opacity | 0.6px | No |

### 4. Overlay rendering: keep CustomPaint with camera sync (not MapLibre native layers yet)

**Chosen**: Keep the `_FlightOverlayPainter` `CustomPaint` approach but replace the manual `_toScreen()` projection with `controller.toScreenLocations()`.

**Alternatives considered**:
- *Migrate to MapLibre GeoJSON source + native line/circle/symbol layers*: Perfect geo-sync for free, better GPU performance. But: the vario-gradient-colored track requires per-segment color which MapLibre's `line-gradient` doesn't support per-vertex in the Dart wrapper; symbol layers for the pilot marker would need custom SDF icons. Larger refactor, riskier scope.

**Rationale**: Smallest change that fixes the geo-sync problem. The `CustomPaint` overlay runs on the Flutter raster thread, not the GPU thread — but with batch `toScreenLocations()` the projection cost is negligible. `shouldRepaint()` already returns `true` on every camera change — correct behavior for camera-synced painting. Follow-up migration to native layers can be done incrementally.

**Latency budget** for overlay repaint path:
| Step | Cost |
|---|---|
| `onEvent(MapEventMoveCamera)` dispatch | <0.1ms |
| `setState()` → framework mark dirty | <0.1ms |
| `toScreenLocations()` (200 points) | <0.5ms |
| `CustomPaint.paint()` (track + airspace + thermals + pilot) | ~1-2ms |
| **Total** | **<3ms per frame** |

Well within a 16ms frame budget (60fps). No jank expected.

## Risks / Trade-offs

**[Risk] `toScreenLocations()` called every frame for 200+ points may become expensive with very long track histories**
→ Mitigation: The `mapTrackHistoryMinutes` parameter (default 10 min) already bounds the point count. For a 1-second GPS interval, that's ~600 points max. Batch `toScreenLocations()` is a single native bridge call. If profiling shows this is hot, the first optimization is to cache screen positions and invalidate only when the `MapCamera` changes (it's an `@immutable` value type with proper `==`).

**[Risk] Contour line data may significantly increase per-region download size**
→ Mitigation: `tippecanoe` with appropriate simplification (`--simplification=10` at low zoom) and `--drop-densest-as-needed` keeps the contour archive compact. Budget: <50 MB per typical Alpine region. Contours are an optional download, not mandatory.

**[Risk] Hillshade exaggeration value may need tuning per-region (Alps vs. flatlands)**
→ Mitigation: Start with 0.5 (moderate). The value is in the style JSON, easily adjustable. Future: per-region style overrides or a user preference.

**[Risk] Removing `GestureDetector` may break any other tap/long-press handling on the map**
→ Mitigation: The current `GestureDetector` only handles `onPanUpdate` — no tap or long-press handlers. MapLibre emits `MapEventClick` and `MapEventLongClick` events, which can be used if tap handling is needed later.

**[Risk] `shouldRepaint()` returning `true` unconditionally causes unnecessary repaints when camera hasn't changed**
→ Trade-off accepted for now. The `MapEventMoveCamera` event only fires when the camera actually moves, so `setState()` is only called on real changes. The painter always gets a fresh camera anyway. If needed later, compare `MapCamera` objects in `shouldRepaint()`.
