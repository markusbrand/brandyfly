## Why

The flight map stutters: the camera jumps once per telemetry fix (1 Hz live GPS / IGC replay), track-up rotation snaps by up to ~18° per fix while circling, raw heading jitter makes the map wobble, and the flight track / pilot marker are painted by Flutter on top of the native MapLibre platform view, so they "swim" against the base map by a frame whenever the camera moves. On long flights, the overlay additionally issues one JNI `toScreenLocation` call per track point per paint and replay copies the whole track every tick, adding UI-thread jank. A flight instrument must present position and orientation fluidly and without visual jitter.

## What Changes

- Add a display-rate map motion loop (vsync `Ticker`) that drives the MapLibre camera continuously instead of jumping per fix:
  - dead-reckons the pilot position between fixes from the observed fix-to-fix motion, converges smoothly onto each new fix, freezes when data is stale, snaps on large jumps / replay seeks;
  - low-pass filters the heading (angle-unwrapped, critically damped) for track-up bearing and marker rotation;
  - issues exactly one camera update per frame (position + bearing + zoom together) and stops ticking when nothing moves.
- Render the flight track, the mock airspace polygon and the free-floating pilot marker as native MapLibre style layers (GeoJSON sources + `line` / `fill` / `symbol` layers) so they are drawn in the same GL frame as the base map. The Flutter `_FlightOverlayPainter` and its per-point JNI projection are removed.
- Track layers are split into an incrementally updated "head" source and periodically rebuilt "window" / "older tail" sources; the configured track history window (`mapTrackHistoryMinutes`) and muted older tail (`mapTrackShowOlderTail`) are actually applied (currently ignored by the painter).
- Hot-path cleanup: the map widget is no longer fully rebuilt on every telemetry tick (telemetry feeds the motion controller; only HUD text rebuilds on value change), replay no longer copies the full track per tick, and duplicate camera calls per tick are removed.
- Track-up anchoring via camera padding: in track-up mode the glider sits at 50 % width / 60 % from the top (forward look-ahead), as already required by `center-glider-map-with-auto-recenter`; north-up stays truly centered.
- Smoothing is presentation-only: telemetry values, recorded IGC data, logbook statistics and replay output are unchanged.

### Non-goals

- No change to sensor sampling rates, GNSS filtering, or the telemetry/replay data model values (no smoothing of recorded or logged data).
- No migration of real OpenAir airspace rendering (`AirspaceMapLayer`) to native layers; it stays a Flutter overlay in this change (follow-up).
- No changes to `ThermalMapWidget` (thermal radar), map styles, tile pipeline, or KK7 heatmap behavior.
- No 3D/pitched camera, no new user settings (smoothing constants are internal).

### Safety, offline, privacy, licensing

- Safety: displayed position may lead or lag the last fix by at most a bounded prediction horizon; on stale data the marker/camera freezes instead of extrapolating indefinitely, and a large jump snaps immediately so the pilot never sees a fabricated path.
- Offline: fully on-device; no network use added.
- Privacy / licensing: no new data leaves the device; no new dependencies (uses existing `maplibre` 0.3.6 style APIs).

## Capabilities

### New Capabilities
- `map-motion-smoothing`: display-rate camera/marker motion between telemetry fixes — prediction, convergence, heading filtering, stale/jump handling, frame-loop lifecycle, presentation-only guarantee.
- `native-map-flight-overlays`: flight track (vario-colored window, muted older tail), mock airspace and pilot marker rendered as native MapLibre layers with incremental source updates, and scoped rebuilds of the map widget.

### Modified Capabilities
- `offline-vector-map-rendering`: "Flight overlay preservation" and "Low-Latency Telemetry and Vario Synchronization" change from Flutter overlays drawn on top of the map to overlays rendered inside the MapLibre frame, moving smoothly between fixes.
- `center-glider-map-with-auto-recenter`: "Continuous Glider Centering" and "Orientation-Specific Viewport Anchoring" now require continuous (non-stepping) follow, filtered track-up rotation, and padding-based 60 % anchoring.

## Impact

- Code: `apps/mobile/lib/ui/features/map/views/map_widget.dart` (major rework), new `ui/features/map/view_models/map_motion_controller.dart` (+ pure smoothing math in `domain/`), new native overlay manager (e.g. `services/map_flight_layers.dart`), `services/maplibre_map_service.dart` (camera padding, per-frame move), `ui/features/flight_canvas/views/widget_slot.dart` (map no longer rebuilt per tick), `services/flight_replay_service.dart` (no full-track copies per tick).
- Tests: `test/map_widget_integration_test.dart`, `test/vario_track_gradient_test.dart` and `test/support/headless_maplibre.dart` currently inspect `_FlightOverlayPainter`; they move to asserting GeoJSON/layer calls on the headless platform plus new unit tests for the smoothing math.
- Platforms: Android, iOS and web map renderers via `maplibre` style APIs; device/emulator verification required (host-GPU emulator per `docs/development.md`).
