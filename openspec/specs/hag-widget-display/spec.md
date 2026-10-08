# hag-widget-display Specification

## Purpose
Displays live pilot height above ground (HAG) in meters by subtracting terrain DEM ground elevation from barometric altitude, with graceful fallback when outside coverage.

## Requirements

### Requirement: Live HAG display
The HAG widget SHALL display the pilot's height above ground computed from barometric altitude minus ground elevation.

#### Scenario: HAG during flight
- **WHEN** the flight telemetry provides a barometric altitude and the ElevationService returns a ground elevation for the pilot's position
- **THEN** the HAG widget displays `barometric_altitude - ground_elevation` in meters, updated at telemetry rate

#### Scenario: No ground elevation available
- **WHEN** the ElevationService returns null (outside downloaded regions)
- **THEN** the HAG widget displays a dash or "---" indicator instead of a numeric value
