## Why

Offline map rendering is central to BrandyFly and must remain responsive while
flight telemetry is active. The Flutter MapLibre binding must therefore be
selected through repeatable measurements with realistic Alpine data rather than
API familiarity or demo performance.

## What Changes

- Build a reproducible benchmark application and representative local PMTiles
  fixture for the modern `maplibre` package and the `maplibre_gl` fallback.
- Exercise offline startup, pan, zoom, rotation, track updates, airspace
  polygons, pilot markers, heatmap-like overlays, contours, and hillshade.
- Measure frame pacing, startup latency, memory, package compatibility, and
  offline failure behaviour on representative Android and iOS devices.
- Record a single engine decision, rejected alternative, known gaps, and
  migration boundary for later map features.

Non-goals:

- Deliver downloadable production map packages or final visual styling.
- Build the complete Alpine-region data pipeline.
- Implement navigation, airspace warnings, live pilots, or thermal overlays.
- Benchmark Web or Linux preview performance as a substitute for mobile devices.

## Capabilities

### New Capabilities

- `offline-map-engine-validation`: Defines repeatable functional and performance
  gates for selecting BrandyFly's offline mobile map engine.

### Modified Capabilities

None.

## Impact

The change affects the Flutter app, small redistributable map fixtures, benchmark
instrumentation, CI smoke coverage, and an architecture decision record. Test
data must carry explicit attribution and redistribution rights. No online tile
service may be required for an offline benchmark pass.
