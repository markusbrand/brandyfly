## 1. Rust Flight Core: Circling Detection & Heading Tracking

- [ ] 1.1 Implement `HeadingTracker` in `crates/flight_core/src/circling.rs` to compute normalized angular delta and track turn rate.
- [ ] 1.2 Implement `CirclingStateDetector` with state machine:
  - Transition from `GLIDING` to `CIRCLING` upon accumulating $\ge 270^\circ$ heading rotation in $\le 25.0$ seconds.
  - Transition from `CIRCLING` to `GLIDING` upon maintaining heading within $\pm 15.0^\circ$ for $\ge 8.0$ seconds.
- [ ] 1.3 Add unit tests in `crates/flight_core` verifying threshold timings, direction detection (left/right), and noise rejection.

## 2. Rust Flight Core: Wind Drift Estimation & Airmass Core Calculation

- [ ] 2.1 Implement `WindEstimator` detecting full $360^\circ$ turn completions and computing horizontal wind drift vector from 2+ turns.
- [ ] 2.2 Implement `ThermalCoreCalculator` computing lift-weighted center of gravity ($w_i = \max(0, c_i)^2$) and airmass coordinate transformation $P_{\text{air}}(t) = P_{\text{gps}}(t) - \vec{V}_{\text{wind}} \cdot (t - t_0)$.
- [ ] 2.3 Define `ThermalStateSnapshot`, `WindVector`, and `ThermalCoreEstimate` data structures in `flight_core`.
- [ ] 2.4 Add unit and property-based tests for wind drift math, turn integration, and core centroid calculation.

## 3. Telemetry Integration & Mock Flight Simulation

- [ ] 3.1 Integrate circling detector, wind estimator, and thermal core calculator into `BoundedFlightPipeline`.
- [ ] 3.2 Update `SyntheticReplayGenerator` and local mock flight mode (`BRANDYFLY_LOCAL_MOCK_FLIGHT_MODE`) to generate realistic thermaling spiral scenarios with ambient wind drift.
- [ ] 3.3 Add regression tests in `crates/flight_core` verifying pipeline determinism and latency budgets.

## 4. Mobile App UI: High-Contrast Dynamic Thermal Assistant Visualizer

- [ ] 4.1 Update Dart telemetry models and services in `apps/mobile` to ingest `ThermalStateSnapshot` and wind vectors.
- [ ] 4.2 Upgrade `ThermalMapWidget` (`apps/mobile/lib/widgets/flight/thermal_map_widget.dart`):
  - Implement XCtrack-grade high-contrast climb color grading (Green $>1.5$, Light Green $0.2..1.5$, Orange $-0.5..0.2$, Red $<-0.5$) with dark outline strokes.
  - Implement animated pulsing thermal core marker and guidance vector from glider to core center.
  - Implement aerodynamic wind arrow overlay and numerical speed/direction pill.
- [ ] 4.3 Add coordinate frame toggle (Ground track vs. Wind-compensated airmass track).
- [ ] 4.4 Update `UIConfig` and settings panel to support dynamic thermal visualizer options.

## 5. Automated Tests & Verification

- [ ] 5.1 Add Rust unit tests in `crates/flight_core` for circling transitions, wind drift estimation, and thermal core math.
- [ ] 5.2 Add Flutter widget and model tests in `apps/mobile/test/` for thermal visualizer rendering, color stops, and wind arrow.
- [ ] 5.3 Verify static analysis and full test suite passes (`cargo test`, `flutter test`, `flutter analyze`).
