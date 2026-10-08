# Deterministic OpenAir Airspace Parser and 3D Proximity Detection

## Why

Paragliding and hang gliding pilots navigate complex, dynamic airspace environments consisting of controlled zones (CTR, Class A–E), restricted areas, military zones, and danger areas. Inadvertent airspace infringement poses severe aviation safety risks and legal penalties.

Executing geometric point-in-polygon tests, circular arc approximations, and multi-reference vertical profile calculations directly in the Flutter UI thread introduces frame drops and UI latency during flight. Furthermore, airspaces are defined in various vertical reference systems (Flight Level standard pressure, MSL barometric altitude, AGL terrain height, and GND/SFC) requiring dynamic, real-time conversion against live QNH pressure settings and digital elevation models (DEM).

By offloading OpenAir parsing, 2D R-Tree spatial indexing, and high-frequency 3D intersection/proximity checks to the deterministic Rust core (`crates/flight_core`), BrandyFly guarantees sub-millisecond proximity evaluations, robust multi-tiered warning states, and smooth 60fps vertical profile rendering on mobile and desktop platforms.

## What Changes

1. **Rust OpenAir Parser & AST (`crates/flight_core`)**:
   - Deterministic parser for OpenAir format files (`.txt`, `.openair`), extracting airspace metadata, classes (Class A–G, CTR, Prohibited, Restricted, Danger, Warning, Glider Sector), vertical floor/ceiling specifications, and 2D boundaries (polygons, circles, arcs).
   - High-fidelity arc/circle discretization converting circular geometries into closed planar polygons with bounded chord error.

2. **Spatial Indexing & 2D/3D Proximity Engine (`crates/flight_core`)**:
   - In-memory 2D R-Tree bounding box spatial index enabling fast $O(\log N)$ spatial queries.
   - Point-in-polygon ray-casting and segment distance algorithms computing exact horizontal separation to airspace boundaries.
   - Dynamic vertical clearance evaluator converting FL (standard atmosphere), AGL (terrain DEM relative), MSL, and GND to absolute meters MSL based on live QNH.
   - Multi-tier proximity trigger state machine with hysteresis (Advisory, Warning, Violation).

3. **Native Bridge & Mobile Service (`plugins/brandyfly_native`, `apps/mobile`)**:
   - High-performance FFI boundary to load OpenAir data and query airspace proximity states per flight frame.
   - Dart `AirspaceService` managing loaded airspace catalogues, active warning broadcasts, and UI event feeds.

4. **UI Airspace Profile & Map Visualization (`apps/mobile`)**:
   - Vertical side-cut widget rendering the glider's projected glide slope against nearby airspace floors/ceilings along current track/heading.
   - Map overlay rendering color-coded airspace boundaries and pulsed alert highlights on the tactical map.
   - Top alert banner surfacing immediate proximity warnings with horizontal/vertical clearance metrics.

## Capabilities

- **Deterministic OpenAir Ingestion**: Parse single or multiple OpenAir files without blocking UI or flight telemetry streams.
- **QNH-Aware Vertical Reference Resolution**: Dynamically convert standard pressure altitudes (FL) and terrain-relative altitudes (AGL) to absolute MSL meters.
- **3-Tier Proximity Warning Triggers**:
  - **Level 1 (Advisory)**: Horizontal distance $< 1000\text{ m}$ OR Vertical distance $< 150\text{ m}$.
  - **Level 2 (Warning)**: Horizontal distance $< 500\text{ m}$ OR Vertical distance $< 75\text{ m}$.
  - **Level 3 (Violation)**: Inside horizontal polygon AND within vertical floor/ceiling limits.
- **Glider Glide Slope Projection**: Project aircraft descent path along current track to predict potential forward airspace penetration.
- **Side-Cut Profile View**: Real-time cross-section profile widget showing terrain elevation, glider altitude, and airspace ceilings/floors ahead.

## Non-Goals

- Live dynamic NOTAM web-scraping or continuous web network ingestion during flight.
- Volumetric 3D CAD mesh rendering (focus is 2D map overlay and 2D vertical side-cut profile).
- Automated flight path steering or autopilot avoidance commands.

## Impact

- Zero-latency 3D airspace awareness with guaranteed frame budgets.
- Extends `crates/flight_core` with deterministic spatial algorithms and comprehensive test fixtures.
- Seamless integration with existing map widgets, thermaling screen, and mock flight replay systems.
