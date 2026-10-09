## 1. Motion smoothing core (pure Dart)

- [x] 1.1 Create `apps/mobile/lib/domain/map_motion/motion_smoother.dart` with `Fix`, `DisplayState` and `MotionSmoother` (velocity from wall-clock fix deltas, 2.0 s prediction horizon, exponential convergence τ≈0.12 s, 300 m / explicit-reset snap, stale hold) and verify with `flutter test test/domain/map_motion/motion_smoother_test.dart` covering: continuous output between 1 Hz fixes (≤25 % per-frame step), 4x replay rate, horizon stop, 15 m blend <0.5 s, 300 m snap, stale hold
- [x] 1.2 Add the critically damped heading filter (shortest-angle, ground-speed hold) to the smoother and verify unit tests for 18°/s circling continuity, ±3° jitter <3° peak-to-peak, and 355°→5° wrap
- [x] 1.3 Add a determinism test: the same fix/time sequence yields identical `DisplayState` sequences, verified in the same test file

## 2. Map motion controller and camera

- [x] 2.1 Add `ui/features/map/view_models/map_motion_controller.dart` (Ticker-driven, subscribes to `ValueListenable<CockpitTelemetry>`, one `CameraTarget` per frame, auto-stops when converged/idle) and verify with a `fake_async`/widget test that one fix sequence produces per-frame `moveCamera` calls and that the ticker stops after the horizon
- [x] 2.2 Extend `MapLibreMapService.moveCamera` with `padding` and add a combined `CameraTarget` write; verify with a recording headless platform test that center, zoom, bearing and padding arrive in a single call
- [x] 2.3 Route zoom steps, recenter (eased ≈600 ms to the displayed pilot position) and orientation switch through the controller (no `animateCamera`), and verify `test/ui/map_controls_test.dart` plus new tests for eased recenter and zoom
- [x] 2.4 Implement track-up padding (top = 20 % of viewport height, eased on orientation switch) and verify a test asserting padding values for north-up (0) and track-up (0.2·h)
- [x] 2.5 Replace `_isProgrammaticMove` timers with `CameraChangeReason.apiGesture` + Flutter pan detection for manual-pan release; verify tests: programmatic per-frame moves never release center-lock, a gesture does, and the inactivity timer recenters

## 3. Native flight overlay layers

- [x] 3.1 Create `services/map_flight_layers.dart` that adds `bf-airspace-mock`, `bf-track-tail`, `bf-track-window`, `bf-track-head`, `bf-pilot` sources/layers below `thermalBelowLayerId` and re-adds them on every style load; verify with a recording `StyleController` in `test/support/headless_maplibre.dart` (layers present after load and after a simulated reload)
- [x] 3.2 Implement track GeoJSON building: history window split (`mapTrackHistoryMinutes`, 0 = full), muted older tail only when `mapTrackShowOlderTail`, merged same-color segments using `MapWidget.getVarioTrackColor` (0.1 m/s buckets); verify `test/vario_track_gradient_test.dart` rewritten against feature colors and new window/tail tests (30 min flight, 10 min window, tail on/off)
- [x] 3.3 Implement incremental updates: head source per new fix, window/tail rebuild every 10 s or >120 head points or on settings/flight reset; change detection by length + last timestamp; verify a test with a 10,800-point flight that a new fix sends only head data and full rebuilds are throttled
- [x] 3.4 Add the pilot symbol image via `addImageFromCanvas` with `icon-rotate` from the filtered heading, visible only while center-lock is released, updated at ≤15 Hz; verify a test toggling lock state switches between Flutter marker and native symbol visibility
- [x] 3.5 Handle overlay update failures (log, keep previous state, retry with current data on next update); verify a test with a throwing `updateGeoJsonSource` that keeps the map and telemetry running

## 4. MapWidget rework

- [x] 4.1 Rework `ui/features/map/views/map_widget.dart`: remove `_FlightOverlayPainter` and per-point `toScreenLocation`, wire `MapMotionController` + `MapFlightLayers`, render the screen-anchored Flutter marker while locked, feed the compass from the filtered heading; verify `flutter analyze` is clean and `test/map_widget_integration_test.dart` is updated to assert layer data / camera calls instead of the painter
- [x] 4.2 Keep the static-data path (`pilotPosition`/`trackPoints`/`flightPoints` constructor params) working through the same layer manager and verify `test/widgets_test.dart`, `test/ui/flight_canvas_test.dart` and `test/ui/map_thermal_layer_test.dart` pass
- [x] 4.3 Ensure headless/no-renderer fallback (no controller → no camera/layer calls, HUD + Flutter marker still render) and verify `test/platform_fallback_integration_test.dart` passes

## 5. Hot-path cleanup

- [x] 5.1 Change `widget_slot.dart` to build `MapWidget` once with the telemetry `ValueListenable` (no per-tick rebuild) and put ALT/SPD HUD behind `ValueSelector` on rounded values; verify with `RebuildProbe` a 10 Hz synthetic run does not rebuild the map widget per tick
- [x] 5.2 Replace per-tick `List.unmodifiable` full-track copies in `FlightReplayService.currentTelemetry` with live views and add a seek/reset signal used for snap + layer rebuild; verify `test/flight_replay_service_test.dart` and a new test that replay ticks do not allocate track copies and that seek triggers a snap
- [x] 5.3 Verify presentation-only guarantee: a replay determinism test showing identical telemetry and recorded points with and without the smoothed map mounted (`test/telemetry_latency_and_perf_test.dart` or new test)

## 6. Validation

- [x] 6.1 Run `cd apps/mobile && flutter analyze && flutter test` and confirm all pass
- [ ] 6.2 On the `brandyfly_test_device` emulator (`-gpu host -no-snapshot`) run synthetic thermal-circling and an IGC replay at 1x and 4x in north-up and track-up; record a screen capture confirming continuous camera motion, no track/airspace swim, glider at 60 % from top in track-up
- [ ] 6.3 Profile with `flutter run --profile` (DevTools frame chart) during a long IGC replay (≥2 h flight) and record UI-thread frame times (target: no frames >16 ms attributable to the map) in the change notes; apply the 30 fps cap or isolate GeoJSON encoding only if the target is missed
- [x] 6.4 Run `npx openspec validate --all --strict` and confirm it passes

## Verification notes

- 6.1: `flutter analyze` clean; `flutter test` 648 passed (incl. new `test/domain/map_motion/`, `test/ui/map/`).
- 6.2 (partial, emulator `brandyfly_test_device`, `-gpu host -no-snapshot`, profile build, synthetic mock flight, track-up):
  - Glide: screen recording analysed with sub-pixel phase correlation - map drifts at a steady 6.3 px/s with 0.11 px RMS deviation from straight-line motion (no steps at telemetry ticks); frame pacing median 16.7 ms, max 18 ms.
  - Thermal circling: per-frame rotation measured around the glider anchor - steady ~0.36 deg/frame (~21 deg/s), no 1.8 deg steps at the 10 Hz ticks, no jumps >1 deg; ~10 % of frames are emulator vsync skips of the native map (caught up next frame).
  - Native track, mock airspace fill and labels render; glider anchored at 60 % from the top in track-up.
  - Still open: IGC replay at 1x / 4x and north-up on the emulator, and a real-device smoothness check.
- 6.3 open: DevTools profiling of a >= 2 h IGC replay not yet done (emulator EGL `app_time_stats` during the synthetic flight: avg 16.7 ms, max 17-33 ms).
