# Proposal

## Why

Paragliding cross-country pilots rely heavily on integrated climb rate metrics and thermal session performance data to center lift efficiently and make glide decisions. Instantaneous variometer readouts fluctuate rapidly during a turn, making it difficult to judge true net climb without a rolling average (typically 15–20 seconds, matching a 360° turn). Furthermore, pilots currently lack a dedicated instrument displaying net altitude gain, average climb, duration, and turn count for the active thermal, which is an industry standard in paragliding flight computers (Skytraxx, XCTrack, Flyskyhy, and Naviter SeeYou).

## What Changes

- **Dual-Marker Vario Bar**:
  - Extend `VarioLiftSinkBar` to display both instantaneous climb rate and a rolling integrated averager (default 20 seconds, configurable to 10s, 15s, 20s, 30s).
  - Add visual tick marks / indicator needles on the vertical edge bar and dial for the rolling average.
  - Display digital readouts for both instantaneous and averaged climb values.
  - Add audio lift threshold (`+0.2 m/s`) and strong sink (`-2.0 m/s`) reference notches.

- **Dedicated Thermal Stats Instrument (`thermalStats`)**:
  - Introduce a new widget type `WidgetType.thermalStats` in the 16x32 grid catalog.
  - Track active thermal session state: start altitude, current altitude gain ($\Delta h$), session average climb, elapsed circling time, turn count, and peak climb.
  - Provide automatic transitions: live updates while circling (`isCircling == true`), and retain frozen statistics of the completed thermal with a `LAST THERMAL` badge while gliding.
  - Support size presets: `S` (compact gain & avg), `M` (standard 4-metric grid), `L` (expanded telemetry view with turn stats).

- **Telemetry Pipeline Enhancements**:
  - Maintain a rolling climb sample window in the telemetry pipeline to compute the integrated averager without blocking sensor or audio paths.
  - Compute thermal session metrics upon circling transitions detected by `CirclingStateDetector`.

## Non-Goals

- Modifying the core acoustic audio vario frequency synthesis algorithms (handled separately in `fm-audio-vario-synthesizer`).
- Online cloud synchronization of thermal session statistics.
- Automatic task scoring or FAI triangle calculation (part of future XC task management).

## Capabilities

### New Capabilities
- `thermal-climb-instruments`: Defines requirements for the rolling climb rate averager pipeline, dual-indicator vario presentation, and thermal session statistics tracking (gain, average, duration, turns, peak).

### Modified Capabilities
- `screen-widget-configuration`: Expands the flight screen widget catalog and layout editor to support `thermalStats` and configurable rolling average integration windows on `varioBar`.

## Impact

- **UI & Widgets**: `apps/mobile/lib/domain/models/widget_type.dart`, `widget_catalog.dart`, `ui_config.dart`, `vario_lift_sink_bar.dart`, and a new `thermal_stats_widget.dart`.
- **Domain & Telemetry**: `cockpit_telemetry.dart`, `telemetry_repository.dart`, and thermal assistant state models.
- **Offline / Safety**: 100% offline-first; all rolling averages and session statistics are computed locally on device from barometric/GPS telemetry.
