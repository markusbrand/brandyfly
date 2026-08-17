## 1. Flight Core – Contracts & Types

- [ ] 1.1 Add `ThermaleMarker` type to `packages/contracts/` (position, radius, color enum, vertical_speed, timestamp)
- [ ] 1.2 Add `ThermaleEpisode` type to `packages/contracts/` (ID, start_time, end_time, markers vec, status enum)
- [ ] 1.3 Add `ThermaleDetectionConfig` type to `packages/contracts/` (min_duration_secs, min_altitude_change_m, radius_scale_factor)
- [ ] 1.4 Add thermaling event types to flight core event stream (EpisodeStarted, EpisodeEnded, MarkerGenerated)
- [ ] 1.5 Validate contract changes compile and are usable from both Rust and Dart

## 2. Flight Core – Thermaling Detection Algorithm

- [ ] 2.1 Implement circular-pattern detector in `crates/flight_core/src/thermaling/circling.rs` (detects heading rate ≥ threshold over min duration)
- [ ] 2.2 Implement altitude aggregator in `crates/flight_core/src/thermaling/altitude.rs` (tracks cumulative altitude gain/loss per circle)
- [ ] 2.3 Implement episode state machine in `crates/flight_core/src/thermaling/episode.rs` (IDLE → ACTIVE, closes on straight flight detection)
- [ ] 2.4 Implement circle marker generator in `crates/flight_core/src/thermaling/markers.rs` (emits ThermaleMarker with sized radius from climb/sink rate)
- [ ] 2.5 Add configurable thresholds (min_duration, min_climb, min_sink, radius_scale) to flight core state
- [ ] 2.6 Unit tests for circling detection (mock GPS/heading data)
- [ ] 2.7 Unit tests for altitude aggregation and marker generation
- [ ] 2.8 Integration test: simulate a full thermaling episode with sample flight data
- [ ] 2.9 Cargo fmt, cargo clippy, and cargo test pass for `crates/flight_core/`

## 3. Mobile UI – Screen & Routing

- [ ] 3.1 Create `apps/mobile/lib/screens/thermaling_screen.dart` with MapLibre widget
- [ ] 3.2 Implement circle marker overlay rendering on MapLibre (GeoJSON from ThermaleMarker list)
- [ ] 3.3 Create screen router/page manager that observes flight core thermaling events (Riverpod or Provider)
- [ ] 3.4 Implement auto-switch logic: main screen → thermaling screen on EpisodeStarted event
- [ ] 3.5 Implement grace period timer (default 10s) to prevent rapid toggling
- [ ] 3.6 Add manual override button on thermaling screen to return to main screen
- [ ] 3.7 Update main app router/navigation to include new thermaling screen
- [ ] 3.8 Widget tests for screen switching logic and grace period
- [ ] 3.9 Integration test: mock flight core events and verify screen transitions

## 4. Mobile UI – Thermaling Screen Configuration

- [ ] 4.1 Extend `apps/mobile/lib/services/config_service.dart` to support separate thermaling screen config namespace
- [ ] 4.2 Implement `ThermaleScreenConfig` class (map_source, widget_layout, widget_list)
- [ ] 4.3 Add SharedPreferences persistence for thermaling screen config (read/write, reset to defaults)
- [ ] 4.4 Create `apps/mobile/lib/screens/thermaling_settings.dart` settings panel for map/widget/layout selection
- [ ] 4.5 Integrate thermaling settings into main settings UI (as a subsection or separate page)
- [ ] 4.6 Widget tests for config persistence and UI updates
- [ ] 4.7 Verify main screen config remains separate and unaffected

## 5. Mobile UI – Thermaling Threshold Configuration

- [ ] 5.1 Add thermaling detection config fields to settings UI (min_duration, min_altitude, radius_scale)
- [ ] 5.2 Bind UI controls to flight core config updates via Riverpod/Provider
- [ ] 5.3 Validate user inputs (e.g., duration ≥ 1 sec, altitude ≥ 0.1 m)
- [ ] 5.4 Persist thermaling detection thresholds to SharedPreferences
- [ ] 5.5 Widget tests for threshold settings and validation

## 6. Mobile UI – Circle Marker Visualization

- [ ] 6.1 Implement circle marker color mapping (green for uplift, red for sink)
- [ ] 6.2 Test circle rendering at various zoom levels (fixed visual size or scale with map)
- [ ] 6.3 Implement circle marker sizing formula (vertical speed → radius in pixels, with configurable scale)
- [ ] 6.4 Stress test: render 50–100 circle markers on thermaling screen without lag
- [ ] 6.5 Add optional marker clustering if performance issues emerge at high marker counts

## 7. Offline & Data Lifecycle

- [ ] 7.1 Verify thermaling detection works without network (test in local mock flight mode)
- [ ] 7.2 Verify circle rendering works with offline/cached maps (PMTiles)
- [ ] 7.3 Implement circle marker clearing on new flight session (reset state)
- [ ] 7.4 Test stale/interrupted telemetry handling (e.g., GPS gap during circle)
- [ ] 7.5 Verify app does not crash or degrade gracefully during telemetry gaps

## 8. Testing & Validation

- [ ] 8.1 Run local mock flight mode with deterministic flight data (circular patterns)
- [ ] 8.2 Verify thermaling detection triggers on circular flight and suppresses on straight flight
- [ ] 8.3 Verify circle markers render correctly (color, size, position) on thermaling screen
- [ ] 8.4 Verify screen auto-switches to thermaling and back to main (with grace period)
- [ ] 8.5 Verify thermaling screen config persists across app restarts
- [ ] 8.6 Verify main screen config is unaffected by thermaling screen changes
- [ ] 8.7 Test on Android 10+ and iOS 16+ devices (or emulators)
- [ ] 8.8 Test portrait and landscape orientation changes
- [ ] 8.9 Battery benchmark: measure CPU/battery impact of continuous thermaling detection
- [ ] 8.10 Test with real paragliding flight data (if available)

## 9. Documentation & Code Quality

- [ ] 9.1 Document `ThermaleMarker`, `ThermaleEpisode`, `ThermaleDetectionConfig` types in contracts
- [ ] 9.2 Add doc comments to thermaling detection functions (purpose, inputs, outputs, examples)
- [ ] 9.3 Update `docs/development.md` with thermaling feature overview
- [ ] 9.4 Add README or architecture doc for thermaling screen in `apps/mobile/`
- [ ] 9.5 Flutter analyze passes for `apps/mobile/`
- [ ] 9.6 Verify Rust code is formatted and passes Clippy checks
- [ ] 9.7 Ensure all new commits use conventional commit format

## 10. Feature Flag & Rollback Readiness

- [ ] 10.1 (Optional) Add feature flag for thermaling detection (allow disable if issues arise)
- [ ] 10.2 Verify app functions correctly with thermaling disabled (graceful fallback)
- [ ] 10.3 Document rollback procedure (revert to previous release, disable feature flag)
- [ ] 10.4 Create release notes covering thermaling feature, default thresholds, and known limitations

## 11. Open Questions (Resolve Before/During Implementation)

- **Circle sizing formula:** Determine exact mapping from vertical speed to pixel radius. (e.g., 1 knot = 50px, 2 knots = 100px, or logarithmic scaling?)
- **Grace period tuning:** Is 10 seconds appropriate? Gather feedback from test flights or allow user configuration.
- **Default threshold values:** Confirm 5s min duration, 5m min altitude change, 0.5kt minimum speed are appropriate for expected pilot profiles.
- **Widget selection defaults:** Which widgets should appear on thermaling screen by default? (e.g., uplift, wind, altitude, vario)
- **Max historical circles:** How many old episodes' circles should remain visible on thermaling screen? (session-only, last 10 minutes, last 5 episodes?)
