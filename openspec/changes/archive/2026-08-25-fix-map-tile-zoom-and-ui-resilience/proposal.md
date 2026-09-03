# Change Proposal: Fix Map Tile Zoom Disappearing & UI Resilience

## Why

When zooming the map (via on-screen zoom steppers, pinch gestures, or edit mode initial zoom presets/sliders), raster tiles from OpenStreetMap, OpenTopoMap, and CARTO completely disappear and never reappear once the zoom level exceeds the native server zoom (e.g., zoom level 17.0 for OpenTopoMap or zoom 19.0 for CARTO/OSM). This occurs because `TileLayer.maxZoom` was improperly configured with server limits instead of `maxNativeZoom`, causing `flutter_map` to treat higher zoom levels as out-of-bounds and hiding the entire layer. Furthermore, missing layer keys cause stale tile state on style switches.

Fixing this ensures continuous map visibility during flight, smooth over-zooming/upscaling of tiles, robust offline fallback, and resilient UI behavior during telemetry updates.

## Non-Goals
- Replacing `flutter_map` with an entirely new map engine or vector tile pipeline in this change.
- Altering the non-map telemetry algorithms or native flight computer sensor processing.

## What Changes

- **Fix `TileLayer` zoom boundaries**: Configure `maxNativeZoom` and `minNativeZoom` with tile server bounds (`maxZoom: 22.0`, `minZoom: 1.0`) so tiles scale smoothly across all zoom levels without disappearing.
- **Keyed `TileLayer` on style switch**: Attach distinct `ValueKey` to `TileLayer` to guarantee clean tile recreation when switching between Alpine Topo, Vector HUD, Thermal Radar, and Shaded Relief styles.
- **Contour toggle handling**: Wire the `showContours` switch to adapt map rendering or display appropriate contour styling.
- **Zoom & telemetry synchronization**: Harden `didUpdateWidget` and `onPositionChanged` to keep the map centered and prevent unexpected tile unloading or jumpy repositioning during live/mock telemetry streaming.
- **Automated regression testing**: Add comprehensive widget tests covering over-zoom behavior (> 17.0), rapid style switching, gesture zoom preservation, and UI interaction across instruments.

## Capabilities

### Modified Capabilities
- `screen-widget-configuration`: Expand requirement on `MapWidget` raster tile rendering and offline caching to mandate continuous over-zooming via `maxNativeZoom` up to zoom 22.0, style keying, and resilient gesture tracking.

## Impact

- **Affected Code**: `apps/mobile/lib/widgets/flight/map_widget.dart`, `apps/mobile/lib/services/map_tile_service.dart`, `apps/mobile/test/map_widget_integration_test.dart`
- **Offline / Safety**: Pilots maintain uninterrupted visual orientation and airspace situational awareness at high zoom levels when approaching thermals or landing zones offline.
- **Licensing / Data Governance**: Preserves compliance with OpenStreetMap, OpenTopoMap, and CARTO tile usage policies and user-agent requirements.
- **GitHub Issue**: https://github.com/markusbrand/brandyfly/issues/42
