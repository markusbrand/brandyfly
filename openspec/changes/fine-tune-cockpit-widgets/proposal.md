## Why

Several existing cockpit instruments in BrandyFly rely on static or unconfigured defaults during flight and replay—such as `WidgetType.glide` falling back to a static L/D value when climbing or replaying, numeric and vario instruments being locked to metric units without trend indicators, the altitude sparkline chart using a fixed short sample buffer with uniform stroke color, the airspace side-cut profile using a fixed 10 km lookahead without block inspection, and the flight time widget displaying only elapsed duration as its primary readout. Fine-tuning these cockpit widgets delivers accurate live telemetry feedback, multi-unit support (`m`/`ft`, `km/h`/`kt`/`mph`, `m/s`/`fpm`), richer visual encodings, and interactive inspection without sacrificing 60 fps UI performance or offline reliability.

## What Changes

- **Live Glide Ratio (`WidgetType.glide`)**:
  - Compute real-time smoothed rolling glide ratio (15s integrated groundspeed over sink rate) for both live telemetry and IGC flight replay.
  - Display `∞` when climbing (`vario >= -0.05 m/s` while airborne) and `---` when stationary (`groundspeed < 5 km/h` or no active source/samples), while clamping descending glide ratios to readable bounds (`0.5` to `50.0`).
- **Numeric & Vario Instrument Enhancements (`altitude`, `speed`, `glide`, `hag`, `varioBar`)**:
  - Add per-widget unit preferences in `WidgetPlacementModel` and `WidgetConfigSheet`: `m` vs `ft` for Altitude and HAG, `km/h` vs `kt` vs `mph` for Ground Speed, and `m/s` vs `fpm` for Vario.
  - Add optional trend chevrons (`▲` / `▼`) and custom label overrides for numeric instruments (`altitude`, `speed`, `glide`, `hag`).
- **Altitude Sparkline Chart (`WidgetType.altitudeChart`)**:
  - Color-code sparkline stroke segments and area fill by vertical climb/sink rate (green in lift, cyan in level flight, red/blue in sink).
  - Add configurable time-window lookback in `WidgetConfigSheet` (`2 min`, `10 min`, `30 min`, or `Full Flight`) backed by extended altitude history retention in live and replay telemetry.
- **Airspace Side-Cut Profile (`WidgetType.airspaceSideCut`)**:
  - Add interactive tap-to-inspect on rendered airspace blocks to display a compact HUD tooltip with airspace name, ICAO class, floor/ceiling limits (OpenAir label and resolved MSL altitude), and forward entry/exit distance.
  - Add configurable forward lookahead distance (`5 km`, `10 km`, `20 km`) in `WidgetConfigSheet` and `AirspaceService` ray-casting cache keys.
- **Flight Time & Sunset Countdown (`WidgetType.flightTime`)**:
  - Extend offline solar calculation (`SunriseCalculator`) with pure-Dart NOAA sunset computation (`sunset`).
  - Allow tapping `FlightTimeWidget` in flight mode or configuring its default mode in `WidgetConfigSheet` to cycle the primary readout between **Flight Duration**, **Local Time of Day**, and **Sunset Countdown**.

### Non-Goals

- Introducing brand-new `WidgetType` enum entries (such as Compass Tape, XC Distance, G-Meter, System Status, or standalone Sunset widget, which are tracked separately in #278).
- Modifying the Rust native sensor fusion pipeline or network backend services.
- Requiring network connectivity for sunset calculations or unit conversions (all computations remain 100% offline in pure Dart).

## Capabilities

### New Capabilities

_None (all enhancements extend existing capabilities)._

### Modified Capabilities

- `screen-widget-configuration`: Add per-widget unit selectors (`m`/`ft`, `km/h`/`kt`/`mph`, `m/s`/`fpm`), numeric custom label and trend chevron toggles, live glide climbing/stationary readout states, altitude sparkline lookback window and vario color-coding options, side-cut lookahead distance configuration, and flight time primary mode configuration.
- `hag-widget-display`: Support displaying HAG in either meters (`m AGL`) or feet (`ft AGL`) according to the widget's configured altitude unit while preserving `---` fallback when terrain elevation is unavailable.
- `openair-airspace-parser-3d-proximity`: Add configurable forward lookahead distance (`5 km`, `10 km`, `20 km`) and interactive tap-to-inspect tooltip on airspace blocks in `AirspaceSideCutWidget`.
- `flight-time-and-rtl-instruments`: Add interactive tap-to-cycle and configurable primary readout mode (**Flight Duration**, **Local Time of Day**, **Sunset Countdown** computed offline from GPS position and date) to `FlightTimeWidget`.

## Impact

- **Code**:
  - `apps/mobile/lib/domain/models/ui_config.dart` (`WidgetPlacementModel` serialization, defaults, equality)
  - `apps/mobile/lib/domain/models/cockpit_telemetry.dart` & `apps/mobile/lib/data/repositories/telemetry_repository.dart`
  - `apps/mobile/lib/domain/thermal_assistant/glide_averager.dart` & `apps/mobile/lib/services/flight_replay_service.dart`
  - `apps/mobile/lib/domain/thermal/sunrise.dart` (sunset calculation)
  - `apps/mobile/lib/ui/features/instruments/views/` (`numeric_text_widget.dart`, `vario_lift_sink_bar.dart`, `altitude_sparkline_chart.dart`, `flight_time_widget.dart`)
  - `apps/mobile/lib/widgets/flight/airspace_side_cut_widget.dart` & `apps/mobile/lib/services/airspace_service.dart`
  - `apps/mobile/lib/ui/features/flight_canvas/views/widget_slot.dart`
  - `apps/mobile/lib/ui/features/layout_editor/views/widget_config_sheet.dart`
- **Offline & Safety**: All calculations (rolling L/D, unit conversions, NOAA sunset, sparkline vario coloring, airspace block hit-testing) execute deterministically on-device with zero network calls and bounded O(N) UI rendering cost.
- **Privacy & Licensing**: No external dependencies or telemetry transmissions added; remains MIT-compatible.
