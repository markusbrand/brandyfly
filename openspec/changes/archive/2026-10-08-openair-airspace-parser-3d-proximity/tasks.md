## 1. OpenAir AST, Parser & Geometry Compiler (`crates/flight_core`)
- [x] 1.1 Define OpenAir data models, AST structures, airspace classes, and vertical limit types in `crates/flight_core/src/airspace/ast.rs`
- [x] 1.2 Implement OpenAir text parser supporting records `AC`, `AN`, `AH`, `AL`, `DP`, `DC`, `DA`, `DB`, `V`, `SP`, `SB` with comment and whitespace handling
- [x] 1.3 Implement coordinate parser supporting DMS (`DD:MM:SS N/S`), decimal minutes, and decimal degrees formats
- [x] 1.4 Implement circle and arc discretization converting curved boundaries to planar polygons with chord tolerance $\le 10\text{ m}$
- [x] 1.5 Add comprehensive unit tests and fixtures validating parser against real-world DACH/European OpenAir datasets

## 2. 2D Spatial Index & Distance Engine (`crates/flight_core`)
- [x] 2.1 Implement in-memory 2D R-Tree spatial bounding box index for loaded airspace polygons
- [x] 2.2 Implement local Equirectangular projection and metric Euclidean distance transforms
- [x] 2.3 Implement point-in-polygon ray-casting and segment distance algorithms in `crates/flight_core/src/airspace/spatial.rs`
- [x] 2.4 Add unit tests and microbenchmarks verifying $O(\log N)$ spatial search performance under 10,000+ airspace geometries

## 3. Vertical Altitude & QNH Reference Resolver (`crates/flight_core`)
- [x] 3.1 Implement vertical reference calculator converting FL, ft MSL, m MSL, ft AGL, m AGL, and GND to absolute MSL meters
- [x] 3.2 Implement standard atmosphere and dynamic QNH pressure offset adjustment formula
- [x] 3.3 Integrate digital elevation model (DEM) terrain elevation lookup for AGL ceiling/floor resolution
- [x] 3.4 Add unit tests verifying exact vertical boundary conversions under varied QNH (980–1040 hPa) and terrain elevations

## 4. 3D Proximity Detection & Alert State Machine (`crates/flight_core`)
- [x] 4.1 Implement 3D proximity engine calculating horizontal distance $d_H$, vertical separation $d_V$, and 3D vector to nearest boundary
- [x] 4.2 Implement 3-tier alert trigger logic: Level 1 Advisory ($d_H < 1000\text{m} \lor d_V < 150\text{m}$), Level 2 Warning ($d_H < 500\text{m} \lor d_V < 75\text{m}$), Level 3 Violation
- [x] 4.3 Implement hysteresis state machine with 2-second debounce and +10% separation threshold for alert downgrades
- [x] 4.4 Implement forward track intersection calculator for glide slope projection ($z(x) = h_0 - x / (L/D)$)
- [x] 4.5 Add unit tests verifying alert state transitions, hysteresis, and boundary breach events

## 5. FFI Native Bridge & Dart Airspace Service (`plugins/brandyfly_native`, `apps/mobile`)
- [x] 5.1 Define C-FFI / Native Assets interface in `crates/flight_core` exposing airspace loading, query, and proximity evaluation functions
- [x] 5.2 Implement Dart FFI bindings and method channel fallbacks in `plugins/brandyfly_native`
- [x] 5.3 Implement `AirspaceService` in `apps/mobile/lib/services/airspace_service.dart` managing airspace lifecycle, file imports, and reactive streams
- [x] 5.4 Integrate `AirspaceService` with `FlightTrackingService` to receive real-time GPS, altitude, and QNH telemetry
- [x] 5.5 Add unit tests for `AirspaceService` data conversion and error recovery

## 6. UI Airspace Profile Side-Cut Widget & Map Visualization (`apps/mobile`)
- [x] 6.1 Create `AirspaceSideCutWidget` in `apps/mobile/lib/widgets/flight/` rendering 2D vertical cross-section along flight heading
- [x] 6.2 Render aircraft marker, forward projected glide slope trajectory line, terrain profile, and colored airspace blocks in side-cut view
- [x] 6.3 Create `AirspaceMapLayer` rendering vector polygon boundaries, class labels, and alert highlights on the tactical map widget
- [x] 6.4 Implement `AirspaceWarningBannerHUD` displaying top-priority warning level, airspace name, and clearance distances
- [x] 6.5 Add widget tests verifying side-cut profile painting, glide slope trajectory, and alert banner triggers

## 7. End-to-End Simulation, Benchmarking & Verification
- [x] 7.1 Integrate OpenAir airspace proximity evaluation into local mock flight mode and flight replay engine
- [x] 7.2 Run benchmarks ensuring 3D proximity evaluation executes in $< 1\text{ ms}$ per telemetry cycle on mobile targets
- [x] 7.3 Execute end-to-end flight replay verifying side-cut visual rendering and alert banner notifications during simulated airspace proximity
