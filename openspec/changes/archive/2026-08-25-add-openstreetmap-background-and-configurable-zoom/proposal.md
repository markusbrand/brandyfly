## Summary

Integrate real OpenStreetMap raster tile backgrounds into BrandyFly's `MapWidget` using `flutter_map` with local disk caching for offline in-flight use, and make the map zoom level configurable and persisted per widget.

## Problem Statement

Currently, `MapWidget` renders a purely synthetic vector terrain using a custom painter with procedural gradient rings and trigonometric contour lines. It does not display actual geographic maps, landmarks, roads, terrain features, or geographic projections. Furthermore, the map zoom level is managed as transient internal state and cannot be customized per widget or saved into flight screen configurations.

## Proposed Solution

1. **`flutter_map` Integration**: Replace synthetic background canvas with `flutter_map` to render standard OpenStreetMap and OpenTopoMap raster tiles with geographic coordinate projection (EPSG:3857).
2. **Offline Tile Caching**: Implement local file-based tile caching so previously viewed and pre-cached map tiles remain available during flight in airplane mode / without cellular coverage.
3. **Per-Widget Zoom Level Configuration**: Add `mapZoomLevel` to `WidgetPlacementModel` with configuration controls (slider, stepper, and presets) in the widget configuration dialog, saving zoom settings per screen layout.
4. **Paragliding Overlays**: Project flight breadcrumb trails, airspace polygons, thermal updrafts, and the pilot position marker over geographic coordinates onto the map.
5. **Interactive Controls & Multiple Styles**: Provide in-flight zoom and center-pilot controls, and support switching between OpenStreetMap Standard, OpenTopoMap, Dark/Alpine Vector HUD, and Relief Shaded styles.

## Goals

- Render authentic OpenStreetMap and OpenTopoMap tile backgrounds centered on pilot's geographic GPS coordinates.
- Ensure offline safety with disk-cached tiles and non-blocking failure fallbacks when offline in the air.
- Enable per-widget zoom configuration (default 13.5, customizable from 3.0 to 18.0) persisted across app restarts in `UIConfig`.
- Retain real-time in-flight zoom steppers (+/- buttons) and auto-centering on the pilot marker.
- Comply with OpenStreetMap Tile Usage Policy (User-Agent header and proper attribution).

## Non-Goals

- Bundling gigabytes of global offline vector map data directly into the application binary.
- Implementing complex 3D terrain mesh rendering in this iteration.
- Live internet tracking sharing / multiplayer flight tracking.

## Safety, Privacy & Licensing Impact

- **Safety & Offline Reliability**: Flight telemetry and vario rendering MUST NEVER freeze or degrade if map tile downloads fail, stall, or timeout in flight.
- **Privacy**: No GPS coordinates or pilot telemetry will be leaked to third-party servers; tile requests only query standard XYZ web mercator bounding tiles.
- **Licensing**: Uses OpenStreetMap data (© OpenStreetMap contributors, ODbL) and OpenTopoMap (CC-BY-SA), including visible attribution and standard compliant User-Agent headers.
