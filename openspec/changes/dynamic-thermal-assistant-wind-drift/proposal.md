## Why

Thermal centering is among the most cognitively demanding skills in free flight (paragliding and hang gliding). Thermals rarely rise vertically; ambient horizontal wind tilts and drifts the thermal column, distorting the pilot's ground track into an elongated cycloid or helical spiral.

Without automated wind drift compensation, pilots cannot easily distinguish between drifting out of the thermal core versus normal wind drift. In addition, manual screen switching when entering a thermal distracts from active glider control and airspace lookout.

This change introduces an XCtrack-grade dynamic thermal assistant pipeline featuring:
1. Deterministic Rust-based flight state detection (automatic CIRCLING vs. GLIDING mode transition).
2. Multi-turn wind drift estimation calculating horizontal wind speed and direction directly from GPS track geometry.
3. Wind-compensated airmass coordinate transformation and lift-weighted thermal core centroid calculation.
4. A high-contrast Flutter circling bubble visualizer displaying climb-rate colorized tracks (Green/Orange/Red), estimated thermal core center, and real-time wind vector.

## What Changes

- **Rust `flight_core` (`crates/flight_core`)**:
  - Implement `HeadingTracker` and `CirclingStateDetector`:
    - Track angular rate of turn and cumulative heading change over a sliding time window.
    - Trigger `FlightState::Circling` when heading change reaches $\ge 270^\circ$ within $\le 25$ seconds.
    - Trigger `FlightState::Gliding` when heading stays within $\pm 15^\circ$ for $\ge 8$ seconds.
  - Implement `WindEstimator`:
    - Track individual $360^\circ$ turn completions during circling.
    - Calculate net horizontal drift displacement $(\Delta x, \Delta y)$ across 2+ consecutive full rotations divided by elapsed turn time to estimate wind speed and direction vector.
  - Implement `ThermalCoreCalculator`:
    - Compute lift-weighted center of gravity:
      $$X_{\text{core}} = \frac{\sum w_i \cdot x_i}{\sum w_i}, \quad w_i = \max(0, \text{climb}_i)^2$$
    - Transform GPS ground coordinates into wind-corrected airmass coordinates:
      $$P_{\text{air}}(t) = P_{\text{ground}}(t) - \vec{V}_{\text{wind}} \cdot (t - t_0)$$
    - Emit structured `ThermalStateSnapshot` telemetry events containing flight state, wind vector, core coordinates, and airmass track points.

- **Mobile App (`apps/mobile`)**:
  - Update telemetry data ingestion to receive and store `ThermalStateSnapshot`.
  - Extend / upgrade `ThermalMapWidget` (`apps/mobile/lib/widgets/flight/thermal_map_widget.dart`):
    - Render high-contrast XCtrack-style circling bubbles:
      - Strong climb ($> +1.5\text{ m/s}$): Bright Green (`#00E676`)
      - Moderate climb ($+0.2\text{ to }+1.5\text{ m/s}$): Light Green / Lime (`#76FF03`)
      - Weak / Sink ($-0.5\text{ to }+0.2\text{ m/s}$): Orange (`#FF9100`)
      - Strong sink ($< -0.5\text{ m/s}$): Vivid Red (`#FF1744`)
    - Dynamic bubble sizing ($6\text{px} \to 16\text{px}$) scaling with lift intensity and alpha decay for older points.
    - High-contrast 1px dark border outlines around bubbles for extreme readability in bright sunlight over terrain and maps.
    - Render thermal core center indicator with animated pulsing concentric rings and drift line.
    - Render wind direction arrow overlay with numeric wind speed (km/h) and direction badge.
  - Update local mock flight simulation (`BRANDYFLY_LOCAL_MOCK_FLIGHT_MODE`) to simulate realistic drifting thermals, circling entry, and wind estimation.

## Capabilities

- `flight-state-circling-detection`: Fast, robust heading-rate integration to switch flight state between gliding and thermaling without false triggers.
- `wind-drift-estimation`: Turn-drift based horizontal wind vector calculation across $360^\circ$ turns.
- `airmass-thermal-core-centering`: Real-time coordinate transformation removing ambient wind drift to compute and visualize the stationary thermal core.
- `high-contrast-thermal-visualizer`: Sunlight-readable Flutter canvas widget with climb-colored bubble trail, lift core bullseye, and wind arrow.

## Non-Goals

- Replacing pitot tube / true airspeed sensors (estimation is derived from GPS track drift and barometric vario).
- Multi-kilometer 3D thermal cone modeling across wide altitude bands (scope focuses on real-time centering within the active circling altitude window).
- Overhauling offline map tile downloading or storage.

## Impact

- Zero-cognitive-overhead thermal centering guidance for pilots during flight.
- Clean integration with existing `bounded_pipeline` and `UIConfig` layout system.
