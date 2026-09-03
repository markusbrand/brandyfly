## Context

BrandyFly is a local-first paragliding vario. In flight, network connectivity is unavailable or intermittent. Replacing procedural synthetic canvas drawings with real OpenStreetMap tiles significantly enhances situational awareness, terrain navigation, and landmark recognition.

## Architecture Decisions

### 1. `flutter_map` Engine
Use `flutter_map` (v7) and `latlong2` for cross-platform tile rendering across Linux desktop, Android, and iOS. It provides a lightweight, pure Dart widget hierarchy (`FlutterMap`, `TileLayer`, `PolylineLayer`, `PolygonLayer`, `MarkerLayer`) that integrates seamlessly with Flutter's reactive state and layout management.

### 2. Disk-Backed Offline Tile Cache
Implement a local caching tile provider that checks local file storage before making network HTTP requests, writing retrieved tiles to the application cache directory (`path_provider`). If network is unreachable, it serves cached tiles or renders transparent/solid fallback without blocking the UI thread.

### 3. Widget Model Extension (`WidgetPlacementModel`)
Add `mapZoomLevel` (double, default 13.5, range 3.0–18.0) to `WidgetPlacementModel`. Extend serialization/deserialization and migration logic to persist zoom configuration in `UIConfig`.

### 4. Layer Ordering & Styling
Maintain the paragliding overlay stack:
1. `TileLayer`: OpenStreetMap / OpenTopoMap / Dark HUD / Relief
2. `PolygonLayer`: Airspace boundaries (CTR / TMA)
3. `CircleLayer` / `MarkerLayer`: Thermal updrafts
4. `PolylineLayer`: Active flight breadcrumb path
5. `MarkerLayer`: Pilot location marker with heading rotation
6. Map HUD Controls: Zoom steppers, recenter pilot toggle, dynamic scale bar, and compass rose.

## Trade-offs & Alternatives

- **Vector Tiles (MapLibre Native)**: Explored in spike; rejected for this change due to heavier native binary weight and desktop Linux build complexity during local development. `flutter_map` provides immediate stability, lightweight raster caching, and full desktop/mobile parity.
- **Custom Tile Painter**: Rejected due to unnecessary re-implementation of mercator tile math, pinch-zoom gestures, and layer compositing.
