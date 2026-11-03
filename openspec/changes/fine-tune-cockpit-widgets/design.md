## Context

See `proposal.md` for motivation and capability scope. Currently, `FlightWidgetContent` (`widget_slot.dart`) subscribes to `ValueListenable<CockpitTelemetry>` via `ValueSelector` using quantized integer keys to avoid unnecessary widget rebuilds on 10–50 Hz telemetry ticks. Any enhancements to cockpit instruments must preserve this zero-allocation hot path, backward-compatible `WidgetPlacementModel` JSON serialization, and deterministic IGC replay behavior.

## Goals / Non-Goals

**Goals:**
- Provide accurate rolling L/D with explicit climbing (`∞`) and stationary (`---`) states across both live telemetry and IGC replay without breaking downstream numeric consumers (such as `AirspaceSideCutWidget` glide projection).
- Add per-widget unit conversion (`AltitudeUnit`, `SpeedUnit`, `VarioUnit`), custom labels, and trend chevrons at display-formatting time while keeping internal `CockpitTelemetry` strictly in SI units (`m`, `km/h`, `m/s`).
- Render vario-colored sparkline segments and configurable time-window slices in `AltitudeSparklineChart` with zero per-frame `Paint` allocations.
- Support configurable lookahead distance and tap-to-inspect airspace block tooltips in `AirspaceSideCutWidget` while keeping `AirspaceService` ray-casting cached.
- Extend `SunriseCalculator` with offline NOAA sunset computation and allow `FlightTimeWidget` to cycle between Duration, Local Time, and Sunset Countdown via tap or inspector config.

**Non-Goals:**
- Changing the internal SI units of `CockpitTelemetry`, `TelemetrySnapshot`, or IGC parser models.
- Adding global unit settings that override per-widget configuration without explicit placement fields.

## Decisions

### 1. Live Glide State Representation (`GlideAverager` & `CockpitTelemetry`)
- **Decision**: Keep `CockpitTelemetry.glide` as a finite `double` (default `8.4`, clamped `[0.5, 50.0]`) for geometric consumers like `AirspaceSideCutWidget`, and add `double? liveGlide` to `CockpitTelemetry` (where `null` indicates stationary/no-glide `---`, `double.infinity` indicates climbing `∞`, and a finite value in `[0.5, 50.0]` indicates descending glide). `GlideAverager.calculateLiveGlide()` returns `null` when `meanSpeedKmh < 5.0` or no samples exist, `double.infinity` when `meanClimbMs >= -0.05`, and clamped `-meanSpeedMps / meanClimbMs` otherwise. In `FlightReplayService` / `TelemetryRepository._onReplayChanged`, compute rolling L/D over the trailing 15 seconds of replay `FlightPoint`s rather than hardcoding `8.0`.
- **Alternatives Considered**:
  - *Changing `CockpitTelemetry.glide` to `double?` or allowing `double.infinity` directly in `glide`*: Rejected because `AirspaceSideCutWidget` and existing tests rely on `telemetry.glide` being a finite number for forward slope projection (`lookaheadDistanceM / glideRatio`).
- **Trade-offs**: Zero impact on CPU/battery (`O(W)` over at most 35 samples in `GlideAverager`).

### 2. Per-Widget Unit Conversions, Trend Chevrons, and Custom Labels
- **Decision**: Introduce `AltitudeUnit { meters, feet }`, `SpeedUnit { kmh, knots, mph }`, and `VarioUnit { mps, fpm }` in `ui_config.dart`, stored as optional fields on `WidgetPlacementModel` (`altitudeUnit`, `speedUnit`, `varioUnit`, `customLabel`, `showTrendChevron`). Conversions happen inside `FlightWidgetContent` (`widget_slot.dart`) and `VarioLiftSinkBar` before integer quantization in `ValueSelector` so rebuild throttling matches the displayed unit precision. Trend chevrons (`▲`, `▼`) are derived from `t.climb` (`> +0.2 m/s` up, `< -0.2 m/s` down for altitude/HAG) or short-term delta without extra state listeners.
- **Alternatives Considered**:
  - *Storing converted values in `CockpitTelemetry`*: Rejected because multiple widgets on the same screen may use different units (e.g., one altitude widget in `m` and another in `ft` for FL/imperial airspace cross-checking).
- **Trade-offs**: Preserves `ValueSelector` integer memoization and adds zero overhead when unconfigured.

### 3. Sparkline Vario Color-Coding and Configurable Time Window
- **Decision**: Increase `TelemetryRepository.historyLength` default to `1800` (30 minutes at 1 Hz) and update `FlightReplayService._rebuildAltitudeHistory` to retain up to 1800 points (or full flight history). Add `altitudeChartHistoryMinutes` (`2`, `10`, `30`, `0` = all; default `10`) and `altitudeChartColorByVario` (`bool`, default `true`) to `WidgetPlacementModel`. In `_SparklinePainter`, slice the trailing `N` samples corresponding to the configured window (`minutes * 60` at 1 Hz, or all samples when `0`), and when `colorByVario` is enabled, draw contiguous lift/neutral/sink sub-paths using cached `Paint` objects (`_liftPaint`, `_sinkPaint`, `_linePaint`) rather than allocating a `Paint` per segment.
- **Alternatives Considered**:
  - *Drawing individual `canvas.drawLine` calls with a new `Paint` per sample*: Rejected because 1,800 draw calls per frame increases raster thread cost; batching contiguous climb/sink regime segments into 3 `Path` objects (`liftPath`, `sinkPath`, `flatPath`) keeps draw calls to O(1) per frame.
- **Trade-offs**: Retaining up to 1,800 `double`s uses ~14 KB of memory and keeps GPU path drawing fast on both Android and iOS.

### 4. Airspace Side-Cut Lookahead & Interactive Block Inspection
- **Decision**: Add `sideCutLookaheadKm` (`5`, `10`, `20`; default `10`) to `WidgetPlacementModel` and include `maxDistanceM` in `AirspaceService.getForwardAirspaces` cache key validation. Convert `AirspaceSideCutWidget` to a `StatefulWidget` that tracks `_selectedBlockIndex` (or selected airspace name/distance). Wrap the chart canvas in a `GestureDetector(onTapDown: ...)` that maps the local tap coordinate `(dx, dy)` into `(distanceM, altitudeMsl)` and hit-tests `forwardBlocks` in reverse paint order. When a block is matched, render a compact translucent HUD card at the top-right of the profile showing `name`, `ICAO class`, `floorLabel -> ceilingLabel (resolved MSL)`, and `entry..exit km`.
- **Alternatives Considered**:
  - *Opening a modal dialog on tap*: Rejected because modal dialogs block the entire flight screen during active flight; an in-widget translucent overlay pill/card can be dismissed with a single tap and never obscures other cockpit instruments.
- **Trade-offs**: Hit-testing only runs on discrete user tap events (zero per-frame cost).

### 5. Offline Sunset Calculation & `FlightTimeWidget` Readout Modes
- **Decision**: Add `SunriseCalculator.sunset(...)` in `apps/mobile/lib/domain/thermal/sunrise.dart` using the symmetric NOAA hour-angle transit equation (`jSet = jTransit + omegaDeg / 360.0`), returning a `SunsetResult` (`SunsetAt(DateTime utc)`, `PolarDay`, `PolarNight`). Add `FlightTimeMode { duration, localTime, sunsetCountdown }` to `ui_config.dart` (`flightTimeMode` on `WidgetPlacementModel`). Make `FlightTimeWidget` a `StatefulWidget` initialized from `model.effectiveFlightTimeMode` (and updated in `didUpdateWidget` if the configured default changes), with an `onTap` handler that cycles to the next `FlightTimeMode`.
- **Alternatives Considered**:
  - *Persisting every in-flight tap to `ScreenManagerService` disk storage*: Rejected because frequent in-flight taps should switch the live readout immediately without triggering full-screen layout JSON writes; the default mode is persisted via `WidgetConfigSheet`.
- **Trade-offs**: Pure-Dart trigonometry executes in `< 10 µs` only once per second when `FlightTimeWidget` updates.

## Risks / Trade-offs

- **[Risk] Legacy saved layouts missing new `WidgetPlacementModel` fields** → **Mitigation**: All new fields on `WidgetPlacementModel` are nullable with `effective*` getters falling back to current defaults (`meters`, `kmh`, `mps`, `10 min`, `10 km`, `FlightTimeMode.duration`). Unknown enum values in `fromJson` safely fall back to `null`.
- **[Risk] Tap-to-cycle on `FlightTimeWidget` or tap-to-inspect on `AirspaceSideCutWidget` interfering with Edit Mode selection** → **Mitigation**: In Edit Mode, `EditFrame` wraps widget content in `IgnorePointer(ignoring: true)` (or handles selection gestures at the frame layer), so interactive widget taps only fire during operative flight/replay.
