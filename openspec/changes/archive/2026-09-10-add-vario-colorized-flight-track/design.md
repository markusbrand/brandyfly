## Context & Architecture

BrandyFly renders offline maps using `flutter_map` with vector/raster tiles in `MapWidget`. Previously, `MapWidget` received a flat list of `LatLng` coordinates (`trackPoints`) and rendered a single `Polyline` with one uniform color based on the current instantaneous vario climb rate.

This change upgrades the flight track renderer to process timestamped and vario-attributed flight points, partition the points by timestamp and vario value into segments, and render continuous color-graded polylines.

```
┌────────────────────────────────────────────────────────┐
│ FlightTrackingService / FlightReplayService            │
│ Stream<List<FlightPoint>> (with timestamp & vario)     │
└───────────────────────────┬────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────┐
│ LayoutStrategyContainer (Telemetry Provider)           │
│ Supplies trackFlightPoints to MapWidget                │
└───────────────────────────┬────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────┐
│ MapWidget & Track Gradient Processor                   │
│ 1. Filter: Window points [Now - N min, Now]            │
│ 2. Color Mapping: Piecewise lerp on vario              │
│ 3. Batching: Merge contiguous points with close colors │
│ 4. Output: Polylines to flutter_map PolylineLayer      │
└────────────────────────────────────────────────────────┘
```

## Gradient Color Stops & Interpolation

We define a piecewise linear color interpolation function $C(v)$ using Dart's `Color.lerp`:

```dart
Color getVarioTrackColor(double vario) {
  if (vario <= -3.0) return const Color(0xFF991B1B); // Dark Red
  if (vario < -1.5) {
    final t = (vario - (-3.0)) / (-1.5 - (-3.0));
    return Color.lerp(const Color(0xFF991B1B), const Color(0xFFEF4444), t)!;
  }
  if (vario < -0.5) {
    final t = (vario - (-1.5)) / (-0.5 - (-1.5));
    return Color.lerp(const Color(0xFFEF4444), const Color(0xFFFCA5A5), t)!;
  }
  if (vario <= 0.5) {
    return const Color(0xFF94A3B8); // Slate Grey
  }
  if (vario < 1.5) {
    final t = (vario - 0.5) / (1.5 - 0.5);
    return Color.lerp(const Color(0xFF86EFAC), const Color(0xFF22C55E), t)!;
  }
  if (vario < 3.5) {
    final t = (vario - 1.5) / (3.5 - 1.5);
    return Color.lerp(const Color(0xFF22C55E), const Color(0xFF15803D), t)!;
  }
  return const Color(0xFF15803D); // Dark Emerald Green
}
```

## Performance & Segment Batching

- **Problem**: In a 10-minute window at 1 Hz GPS sampling, there are 600 points. Creating 600 individual 2-point `Polyline` widgets every frame can degrade UI performance on mobile devices.
- **Solution**:
  1. Consecutive points that fall within a small color delta (or the same discrete bucket) are batched into a single multi-point `Polyline`.
  2. A 2-point overlap between adjacent segments ensures smooth visual connectivity without gaps at segment joints.
  3. Pre-allocated `Polyline` lists are rebuilt only when new points arrive or zoom/pan events trigger redraws.

## UI Settings & Model Persistence

`WidgetPlacementModel` is extended with:
- `mapTrackHistoryMinutes` (int, default `10`, range `1..120` or `0` for all)
- `mapTrackShowOlderTail` (bool, default `true`)

These are surfaced in:
- The quick settings sheet when long-pressing / inspecting the Map widget in edit mode.
- The global Map settings category in `UISettingsPanel`.

## Risks & Trade-offs

- **Risk**: Line visibility against varying map tile styles (snow, forests, satellite imagery).
  - **Mitigation**: All track polylines retain a thin dark border stroke (`borderColor: Colors.black87`, `borderStrokeWidth: 1.2`) ensuring high contrast across all terrain backgrounds.
- **Risk**: Backward compatibility with simple `List<LatLng>` inputs in tests.
  - **Mitigation**: `MapWidget` accepts both `List<FlightPoint>? flightPoints` and fallback `List<LatLng>? trackPoints`, calculating color gradients whenever vario telemetry is present.
