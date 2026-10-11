# Tasks

## 1. Domain Models and Telemetry Pipeline

- [x] 1.1 Implement `ThermalSessionStats` domain model capturing entry altitude, net altitude gain ($\Delta h$), session average climb, duration, turn count, and peak climb; verify with unit tests in `test/domain/thermal_assistant/thermal_session_stats_test.dart`.
- [x] 1.2 Implement rolling climb rate averager queue (configurable 10s, 15s, 20s, 30s) in telemetry processing; verify with unit tests in `test/domain/telemetry/climb_averager_test.dart`.
- [x] 1.3 Extend `CockpitTelemetry` and `ThermalAssistantEngine` to track circling state transitions, updating live session stats while circling and freezing the last thermal upon returning to straight glide; verify with state transition tests.

## 2. VarioLiftSinkBar Dual-Indicator Enhancement

- [x] 2.1 Extend `VarioLiftSinkBar` to render a distinct rolling average needle marker on the vertical edge bar and analog dial alongside reference threshold notches (+0.2 m/s lift, -2.0 m/s sink); verify with widget tests in `test/widgets/flight/vario_lift_sink_bar_test.dart`.
- [x] 2.2 Add dual digital climb readouts (`instant` and `ø average`) in `VarioLiftSinkBar` regular tier; verify responsive scaling across tiny, compact, and regular tiers.
- [x] 2.3 Expose averager window duration selector and marker visibility toggle in widget configuration dialog; verify settings persistence in `UIConfig`.

## 3. Dedicated Thermal Stats Widget

- [x] 3.1 Add `WidgetType.thermalStats` to `widget_type.dart` and register its specifications in `widget_catalog.dart` with minimum bounds (3x2) and presets (S: 4x3, M: 6x4, L: 8x5, Full: 16x8); verify layout catalog tests pass.
- [x] 3.2 Implement `ThermalStatsWidget` in `apps/mobile/lib/ui/features/instruments/views/thermal_stats_widget.dart` supporting live circling mode, frozen `LAST THERMAL` view, and responsive content tiers; verify with widget tests in `test/widgets/flight/thermal_stats_widget_test.dart`.
- [x] 3.3 Integrate `ThermalStatsWidget` into `flight_canvas` widget slots, widget picker sheet, and layout migration logic; verify placement in layout editor.

## 4. Verification and Validation

- [x] 4.1 Run full Flutter test suite (`flutter test`) verifying all telemetry, layout, and widget tests pass.
- [x] 4.2 Run `npx openspec validate --all --strict` and confirm zero specification warnings or schema errors.
