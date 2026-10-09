## Context

See proposal.md (Why). Current pipeline (`map_widget.dart`, `widget_slot.dart`):

- `widget_slot.dart` wraps `MapWidget` in a `ValueListenableBuilder` on the full `CockpitTelemetry`, so every tick (synthetic 10 Hz, replay/live ≈1 Hz) rebuilds the whole map subtree.
- `didUpdateWidget` calls `_updateCamera()` → `MapLibreMapService.moveCamera` (an instant, synchronous JNI/FFI call) once for position and again for heading, so the camera steps once per fix.
- Track, pilot marker and mock airspace are drawn by `_FlightOverlayPainter` (Flutter canvas) on top of the MapLibre platform view (Android default `tlhc_vd` + texture mode). Each vertex is projected with a synchronous `toScreenLocation` JNI call against the *current* native camera, which is composited independently of the Flutter frame → one-frame phase error ("swim"). A Mercator fallback is used when the call returns (0,0).
- `mapTrackHistoryMinutes` / `mapTrackShowOlderTail` are passed to the painter but ignored.
- `FlightReplayService.currentTelemetry` returns `List.unmodifiable` copies of the full track every tick.
- `maplibre` 0.3.6 offers what we need: `moveCamera(..., padding:)` on Android/iOS/web, `StyleController.addSource/addLayer/updateGeoJsonSource/addImageFromCanvas`, `LineStyleLayer`/`FillStyleLayer`/`SymbolStyleLayer` with expression-valued paint, and `CameraChangeReason.apiGesture` on camera events.

## Goals / Non-Goals

**Goals:**
- Camera motion and track-up rotation at display rate, driven from one place, one camera write per frame.
- Track and airspace rendered in the MapLibre frame; zero per-vertex UI-thread projection.
- Pure, unit-testable smoothing math independent of Flutter and MapLibre.

**Non-Goals:**
- Changing telemetry, recording, or replay data (smoothing lives only in the presentation layer).
- Native rendering of real OpenAir airspaces (`AirspaceMapLayer`), the thermal radar, or tuning UI.
- Moving the motion loop off the UI thread: the per-frame work is O(1) (a few doubles + one camera call); the heavy parts (GeoJSON encoding) are throttled.

## Decisions

### D1. `MapMotionController` + pure `MotionSmoother`
- `domain/map_motion/motion_smoother.dart` (pure Dart, no Flutter): input `Fix(lat, lon, headingDeg, receivedAt, stale)`; output `DisplayState(lat, lon, bearingDeg)` for a given wall-clock time. Fully deterministic given the same fix/time sequence → unit-testable with synthetic clocks.
- `ui/features/map/view_models/map_motion_controller.dart` owns a `Ticker` (via the map state's `TickerProvider`), feeds fixes from the telemetry `ValueListenable` directly (no widget rebuild), and on each tick computes the display state and the camera target.
- **Alternative considered:** native `animateCamera` to each new fix with duration = fix interval. Rejected: animations are cancelled/restarted every fix (visible velocity discontinuities), duration must be guessed, bearing and position cannot be filtered independently, and the overlay/marker would not know the intermediate camera state.
- **Alternative considered:** smoothing inside `TelemetryRepository`. Rejected: would alter telemetry consumed by audio/logging and break the presentation-only / deterministic replay guarantee.

### D2. Position: velocity extrapolation with exponential convergence
- Velocity is estimated from the newest fix and the most recent earlier fix at least 0.5 s older (the previous fix at 1 Hz, a few fixes back for 10 Hz sources to suppress frame-quantization noise), divided by their **wall-clock arrival delta** (fixes are stamped with the next vsync time) (works for live 1–10 Hz and any replay multiplier without knowing the multiplier). The first fix has zero velocity (no fabricated motion from speed/heading).
- Predicted target `p(t) = fix + v·min(t − receivedAt, 2.0 s)` (horizon from the spec).
- The display state is an offset `e` from the target that decays exponentially (`e *= exp(−dt/τ)`, τ ≈ 0.12 s → <5 % residual after 0.5 s). On a new fix, `e` is set to `displayed − newTarget`, so there is no visual jump; this yields a C0-continuous path with a short blend instead of a snap.
- Snap rule: if `|displayed − newFix| > 300 m`, or a replay seek / flight load / source switch is signalled, set `e = 0` and reset velocity.
- Stale/invalid fix: velocity → 0, hold the display; no extrapolation.
- Calculations in a local equirectangular frame around the last fix (meters), which is accurate at these distances and cheap.
- **Alternative considered:** pure interpolation between the last two fixes (render one fix behind). Rejected: adds a constant ≈1 s display latency at 1 Hz, which is unacceptable for a flight instrument. Kalman filter: more tuning and state for no visible benefit at this level; can replace `MotionSmoother` internals later without API change.

### D3. Heading: critically damped angular follow
- Target heading = latest fix heading (if speed < ~5 km/h on the ground, keep the previous heading to avoid noise spinning).
- Error is the shortest signed angle `wrap180(target − displayed)`; display follows a critically damped second-order filter (ω ≈ 4 rad/s) → smooth 18°/s turns with ≈0.25 s lag, ±3° jitter attenuated to <3° peak-to-peak (a linear filter cannot reach <1° without ~40° turn-entry lag; gains α=0.5, β=0.15 referenced to 1 s).
- Implemented as an alpha-beta (angle + turn-rate) filter on the unwrapped course rather than a pure second-order follow, so steady turns are tracked without lag; gains are scaled to the fix interval.
- Same filtered heading is used for track-up bearing and north-up marker rotation; compass widget uses it too.

### D4. Single camera writer per frame
- All camera inputs (follow, zoom buttons, recenter, orientation switch, track-up padding) resolve to one `CameraTarget(center, zoom, bearing, padding)` written via one `moveCamera` per tick. Zoom step changes and recenter are eased inside the same loop (≈250 ms zoom, ≈600 ms recenter), not via `animateCamera`, so they compose with follow.
- The ticker runs while: center-locked and (prediction active or `e`/heading/zoom not converged), or an eased transition is running. Otherwise it stops (battery) and restarts on the next fix/interaction.
- Manual-pan detection uses `MapEventStartMoveCamera.reason == CameraChangeReason.apiGesture` plus the existing Flutter pan handler; the `_isProgrammaticMove` + timer heuristic is removed (it is unreliable with per-frame moves).

### D5. Track-up anchor via camera padding
- Track-up: `padding.top = 0.2 × viewportHeight` → the camera's focal point (pilot) sits at 60 % from the top; north-up: zero padding. Padding transitions are eased with the orientation switch.
- **Alternative considered:** offsetting the camera center geographically ahead of the pilot. Rejected: depends on zoom and bearing and breaks zoom-around-pilot.

### D6. Native overlay layers via `MapFlightLayers`
- New `ui/features/map/layers/map_flight_layers.dart` (presentation layer, next to the pure `track_geojson.dart` builder and `vario_track_palette.dart`) owns sources/layers on the `StyleController` and re-adds them on every `onStyleLoaded` (style reloads remove them). Layers are inserted below the first symbol layer (same anchor as the KK7 layer, `thermalBelowLayerId`) but above the thermal raster so labels stay readable.
- Sources / layers:
  - `bf-airspace-mock` (fill + line) – static polygon, added once.
  - `bf-track-tail` (line, muted thin neutral) – points older than the window; rebuilt on window rebuild.
  - `bf-track-window` (line, `line-color: ["get","c"]`) – in-window segments, consecutive segments with the same quantized vario color (0.1 m/s buckets via `MapWidget.getVarioTrackColor`) merged into one LineString feature to keep feature count low.
  - `bf-track-head` (same style as window) – points since the last window rebuild, updated on every new fix (O(recent points)).
  - `bf-pilot` (symbol, icon from `addImageFromCanvas`, `icon-rotate` from feature property, `icon-rotation-alignment: map`) – only visible while center-lock is released.
- Window rebuild cadence: every 10 s or when the head exceeds 120 points, whichever comes first; also on setting changes and flight reset. GeoJSON encoding is done in Dart on the UI thread but limited to that cadence; if profiling shows >4 ms for very long flights, move encoding to `compute()` (isolate) — the API stays the same.
- Track vertices are recorded fixes only (spec: presentation-only). The head's last vertex is the last fix; the small gap to the predicted marker (≤ one fix interval of travel) is accepted.
- Live tracking reuses the same mutable `UnmodifiableListView` instance; change detection uses `length` + last timestamp, not list identity.
- **Alternative considered:** `MapLibreMap.layers` declarative API. Rejected: it re-serializes the full FeatureCollection whenever a layer changes (O(n) per fix) and offers no control over layer ordering below labels.
- **Alternative considered:** keep the Flutter painter but cache projections. Rejected: cannot fix the compositing phase error between the platform view and the Flutter layer.

### D7. Pilot marker: screen-anchored while locked, native while panned
- Center-locked: a Flutter marker widget at the anchor point (center, or 60 % from top in track-up). The camera puts the displayed pilot position exactly there each frame, so the marker is pixel-stable by construction and needs no projection.
- Unlocked: the Flutter marker is hidden and the native `bf-pilot` symbol is shown, updated at ≤15 Hz from the smoothed state (the camera is not moving then except by gestures, during which the native symbol is geo-locked with the map).
- **Alternative considered:** native symbol at all times updated per frame. Rejected: GeoJSON source updates are applied asynchronously by MapLibre's worker, so a per-frame updated point lags the per-frame camera → the marker would jitter around the anchor, recreating the wobble.

### D8. Rebuild scoping and replay copies
- `widget_slot.dart` builds `MapWidget` without a per-tick `ValueListenableBuilder`; it passes the `ValueListenable<CockpitTelemetry>` instead. `MapWidget` subscribes the motion controller and layer manager directly; the ALT/SPD HUD uses `ValueSelector` on rounded values.
- `FlightReplayService` exposes the growing track as a view (`UnmodifiableListView` over the cache, same pattern as `FlightTrackingService`) instead of copying per tick; a `trackRevision`/seek signal lets the layer manager rebuild on seek and the motion controller snap.
- Without a live source (previews/idle canvas) the demo track around the pilot is kept; with a live source but no recorded track (pre-takeoff) no track is drawn. Only replacement of the recorded track list triggers a snap.
- The legacy `trackPoints`/`flightPoints`/`pilotPosition` constructor parameters stay supported for tests and screenshots (static data path → same layer manager).

### D9. Fallback without a native renderer
- When `controller`/`styleController` is absent (headless tests, unsupported platform), layers are not added and the camera is not moved; the widget still builds HUD and Flutter marker. Tests assert source/layer data through a recording `StyleController` in `test/support/headless_maplibre.dart`.

## Risks / Trade-offs

- [Prediction overshoot when the pilot turns sharply right after a fix] → 2 s horizon, convergence τ 0.12 s; at 1 Hz and 40 km/h worst-case overshoot ≈ 11 m, corrected within 0.5 s without a jump. Track itself always shows true fixes.
- [GeoJSON update latency for the head source] → head lags the camera by a frame at most; acceptable since it only grows at fix rate and is geo-locked once rendered.
- [Per-frame `moveCamera` cost on low-end Android, texture mode] → it is one JNI call; native re-render was already happening during moves. Measure with `flutter run --profile`; if needed cap the loop to 30 fps via frame skipping (internal constant).
- [Battery: continuous ticking in flight] → loop stops when converged/idle; in flight the native map re-renders anyway on every camera change; 30 fps cap available as fallback.
- [Platform-specific behavior of `padding` and symbol `icon-rotate` on web] → verify on web build; fall back to zero padding on web if unsupported (north-up anchor unaffected).
- [Existing tests coupled to `_FlightOverlayPainter`] → rewritten against layer data and motion math; behavior coverage kept (vario colors, history window, airspace anchoring).
- [Emulator rendering artifacts] → verify only with `-gpu host` per `docs/development.md`; final smoothness judgement on a real device.

## Migration Plan

- No persisted data or settings change; existing layouts keep working.
- Rollback: revert the change; no data migration involved.

## Open Questions

- Exact filter constants (τ, ω, snap distance) may be tuned after on-device flights within the bounds set by the specs.
- Whether to also feed the filtered heading to the `ThermalMapWidget` is deferred (out of scope).
