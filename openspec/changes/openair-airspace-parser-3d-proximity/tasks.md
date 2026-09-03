## 1. OpenAir AST, Parser & Geometry Compiler (`crates/flight_core`)
- [ ] 1.1 Define OpenAir data models, AST structures, airspace classes, and vertical limit types in `crates/flight_core/src/airspace/ast.rs`
- [ ] 1.2 Implement OpenAir text parser supporting records `AC`, `AN`, `AH`, `AL`, `DP`, `DC`, `DA`, `DB`, `V`, `SP`, `SB` with comment and whitespace handling
- [ ] 1.3 Implement coordinate parser supporting DMS (`DD:MM:SS N/S`), decimal minutes, and decimal degrees formats
- [ ] 1.4 Implement circle and arc discretization converting curved boundaries to planar polygons with chord tolerance $\le 10\text{ m}$
- [ ] 1.5 Add comprehensive unit tests and fixtures validating parser against real-world DACH/European OpenAir datasets

## 2. 2D Spatial Index & Distance Engine (`crates/flight_core`)
- [ ] 2.1 Implement in-memory 2D R-Tree spatial bounding box index for loaded airspace polygons
- [ ] 2.2 Implement local Equirectangular projection and metric Euclidean distance transforms
- [ ] 2.3 Implement point-in-polygon ray-casting and segment distance algorithms in `crates/flight_core/src/airspace/spatial.rs`
- [ ] 2.4 Add unit tests and microbenchmarks verifying $O(\log N)$ spatial search performance under 10,000+ airspace geometries

## 3. Vertical Altitude & QNH Reference Resolver (`crates/flight_core`)
- [ ] 3.1 Implement vertical reference calculator converting FL, ft MSL, m MSL, ft AGL, m AGL, and GND to absolute MSL meters
- [ ] 3.2 Implement standard atmosphere and dynamic QNH pressure offset adjustment formula
- [ ] 3.3 Integrate digital elevation model (DEM) terrain elevation lookup for AGL ceiling/floor resolution
- [ ] 3.4 Add unit tests verifying exact vertical boundary conversions under varied QNH (980–1040 hPa) and terrain elevations

## 4. 3D Proximity Detection & Alert State Machine (`crates/flight_core`)
- [ ] 4.1 Implement 3D proximity engine calculating horizontal distance $d_H$, vertical separation $d_V$, and 3D vector to nearest boundary
- [ ] 4.2 Implement 3-tier alert trigger logic: Level 1 Advisory ($d_H < 1000\text{m} \lor d_V < 150\text{m}$), Level 2 Warning ($d_H < 500\text{m} \lor d_V < 75\text{m}$), Level 3 Violation
- [ ] 4.3 Implement hysteresis state machine with 2-second debounce and +10% separation threshold for alert downgrades
- [ ] 4.4 Implement forward track intersection calculator for glide slope projection ($z(x) = h_0 - x / (L/D)$)
- [ ] 4.5 Add unit tests verifying alert state transitions, hysteresis, and boundary breach events

## 5. FFI Native Bridge & Dart Airspace Service (`plugins/brandyfly_native`, `apps/mobile`)
- [ ] 5.1 Define C-FFI / Native Assets interface in `crates/flight_core` exposing airspace loading, query, and proximity evaluation functions
- [ ] 5.2 Implement Dart FFI bindings and method channel fallbacks in `plugins/brandyfly_native`
- [ ] 5.3 Implement `AirspaceService` in `apps/mobile/lib/services/airspace_service.dart` managing airspace lifecycle, file imports, and reactive streams
- [ ] 5.4 Integrate `AirspaceService` with `FlightTrackingService` to receive real-time GPS, altitude, and QNH telemetry
- [ ] 5.5 Add unit tests for `AirspaceService` data conversion and error recovery

## 6. UI Airspace Profile Side-Cut Widget & Map Visualization (`apps/mobile`)
- [ ] 6.1 Create `AirspaceSideCutWidget` in `apps/mobile/lib/widgets/flight/` rendering 2D vertical cross-section along flight heading
- [ ] 6.2 Render aircraft marker, forward projected glide slope trajectory line, terrain profile, and colored airspace blocks in side-cut view
- [ ] 6.3 Create `AirspaceMapLayer` rendering vector polygon boundaries, class labels, and alert highlights on the tactical map widget
- [ ] 6.4 Implement `AirspaceWarningBannerHUD` displaying top-priority warning level, airspace name, and clearance distances
- [ ] 6.5 Add widget tests verifying side-cut profile painting, glide slope trajectory, and alert banner triggers

## 7. End-to-End Simulation, Benchmarking & Verification
- [ ] 7.1 Integrate OpenAir airspace proximity evaluation into local mock flight mode and flight replay engine
- [ ] 7.2 Run benchmarks ensuring 3D proximity evaluation executes in $< 1\text{ ms}$ per telemetry cycle on mobile targets
- [ ] 7.3 Execute end-to-end flight replay verifying side-cut visual rendering and alert banner notifications during simulated airspace proximity
