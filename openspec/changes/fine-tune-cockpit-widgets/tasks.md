## 1. Domain Configuration & Live Telemetry Models

- [ ] 1.1 Add `AltitudeUnit` (`meters`, `feet`), `SpeedUnit` (`kmh`, `knots`, `mph`), `VarioUnit` (`mps`, `fpm`), and `FlightTimeMode` (`duration`, `localTime`, `sunsetCountdown`) enums and corresponding per-widget fields (`altitudeUnit`, `speedUnit`, `varioUnit`, `customLabel`, `showTrendChevron`, `altitudeChartHistoryMinutes`, `altitudeChartColorByVario`, `sideCutLookaheadKm`, `flightTimeMode`) to `WidgetPlacementModel` in `apps/mobile/lib/domain/models/ui_config.dart`, and verify round-trip JSON serialization in unit tests.
- [ ] 1.2 Add `calculateLiveGlide()` to `GlideAverager` (`apps/mobile/lib/domain/thermal_assistant/glide_averager.dart`) returning `null` when stationary (`< 5 km/h`), `double.infinity` when climbing (`>= -0.05 m/s`), and clamped `[0.5, 50.0]` when descending; wire `liveGlide` into `CockpitTelemetry`, `TelemetryRepository`, and `FlightReplayService`, and verify with unit tests for climbing, stationary, descending, and replay glide states.
- [ ] 1.3 Add `SunriseCalculator.sunset` (`SunsetResult`, `SunsetAt`, `PolarDay`, `PolarNight`) in `apps/mobile/lib/domain/thermal/sunrise.dart` using the offline NOAA solar algorithm, and verify accuracy against known coordinates and polar edge cases in unit tests.

## 2. Numeric & Vario Instrument Enhancements

- [ ] 2.1 Update `NumericTextWidget` (`apps/mobile/lib/ui/features/instruments/views/numeric_text_widget.dart`) to support optional trend chevrons (`▲` / `▼`) and custom label overrides across regular, compact, and tiny tiers, and verify rendering with widget tests.
- [ ] 2.2 Update `VarioLiftSinkBar` (`apps/mobile/lib/ui/features/instruments/views/vario_lift_sink_bar.dart`) and `FlightWidgetContent` (`apps/mobile/lib/ui/features/flight_canvas/views/widget_slot.dart`) to format `altitude`, `hag`, `speed`, `glide` (including `∞` and `---` states), and `varioBar` according to configured units (`m`/`ft`, `km/h`/`kt`/`mph`, `m/s`/`fpm`), custom labels, and trend chevrons, and verify with widget tests.

## 3. Altitude Sparkline Chart Enhancements

- [ ] 3.1 Update `TelemetryRepository` and `FlightReplayService` to retain up to 1,800 altitude history samples (30 minutes at 1 Hz), and update `AltitudeSparklineChart` (`apps/mobile/lib/ui/features/instruments/views/altitude_sparkline_chart.dart`) to slice history by `historyMinutes` (`2`, `10`, `30`, or `0` = full flight) and render climb/sink color-coded segments (green in lift, cyan neutral, red/blue in sink) with cached `Paint` objects; verify with widget and painter unit tests.

## 4. Airspace Side-Cut Interactive Inspection & Lookahead

- [ ] 4.1 Update `AirspaceService.getForwardAirspaces` (`apps/mobile/lib/services/airspace_service.dart`) to include `maxDistanceM` in its ray-marching cache key so lookahead distance changes invalidate stale cached blocks, and verify with unit tests.
- [ ] 4.2 Update `AirspaceSideCutWidget` (`apps/mobile/lib/widgets/flight/airspace_side_cut_widget.dart`) and `FlightWidgetContent` to accept configurable `lookaheadDistanceM` (`5 km`, `10 km`, `20 km`) and support interactive tap-to-inspect on airspace blocks showing a dismissible HUD tooltip with airspace name, ICAO class, floor/ceiling limits, and entry/exit distance; verify with widget tests.

## 5. Flight Time Widget Modes & Inspector Configuration Sheet

- [ ] 5.1 Update `FlightTimeWidget` (`apps/mobile/lib/ui/features/instruments/views/flight_time_widget.dart`) and `FlightWidgetContent` to support cycling the primary readout between `Flight Duration`, `Local Time of Day`, and `Sunset Countdown` on tap or via configured default mode, and verify with widget tests.
- [ ] 5.2 Update `showWidgetConfigDialog` (`apps/mobile/lib/ui/features/layout_editor/views/widget_config_sheet.dart`) to expose unit selectors, custom label input, trend chevron toggle, sparkline lookback window and vario color toggle, side-cut lookahead distance selector, and flight time primary mode selector, and verify configuration persistence with widget tests.
- [ ] 5.3 Run `flutter analyze` and `flutter test` in `apps/mobile` and `npx openspec validate --all --strict` to confirm zero warnings and all tests pass.
