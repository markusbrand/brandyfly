## MODIFIED Requirements

### Requirement: Live HAG display
The HAG widget SHALL display the pilot's height above ground computed from barometric altitude minus ground elevation in the widget's configured altitude unit (`m AGL` or `ft AGL`).

#### Scenario: HAG during flight
- **WHEN** the flight telemetry provides a barometric altitude, the ElevationService returns a ground elevation for the pilot's position, and the widget altitude unit is set to meters (default)
- **THEN** the HAG widget displays `barometric_altitude - ground_elevation` rounded to whole meters with unit `m AGL`, updated at telemetry rate

#### Scenario: HAG during flight in feet
- **WHEN** the flight telemetry provides a barometric altitude, the ElevationService returns a ground elevation for the pilot's position, and the widget altitude unit is set to feet
- **THEN** the HAG widget displays `(barometric_altitude - ground_elevation) * 3.28084` rounded to whole feet with unit `ft AGL`, updated at telemetry rate

#### Scenario: No ground elevation available
- **WHEN** the ElevationService returns null (outside downloaded regions)
- **THEN** the HAG widget displays a dash or "---" indicator instead of a numeric value
