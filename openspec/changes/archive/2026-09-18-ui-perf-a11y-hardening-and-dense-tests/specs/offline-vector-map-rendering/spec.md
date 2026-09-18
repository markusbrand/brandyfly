## ADDED Requirements

### Requirement: Low-Latency Telemetry and Vario Synchronization
The flight map and instrument widgets SHALL process high-frequency telemetry stream updates without causing main-thread frame skipping or UI render stalls, preserving immediate vario reactivity for paragliding navigation.

#### Scenario: Smooth marker and track updates during flight
- **WHEN** GPS telemetry ticks arrive at 1Hz to 10Hz frequencies during active flight or simulation
- **THEN** the pilot marker position and active track breadcrumbs SHALL update smoothly without triggering full map tile engine reloads or UI jank.

#### Scenario: Optimized custom painter caching
- **WHEN** custom telemetry painters (e.g. vario bar, sparklines, mini tracks) render successive frames
- **THEN** paint paths and stroke styles SHALL be reused or isolated via RepaintBoundaries to prevent unnecessary full-screen repaints.
