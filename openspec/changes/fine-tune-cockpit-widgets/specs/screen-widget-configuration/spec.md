## MODIFIED Requirements

### Requirement: Widget Instance Specific Configuration
Each widget placement on a screen SHALL encapsulate its own visual style, unit preferences, zoom level, and specialized presentation options, falling back to default built-in styles and metric units when unconfigured.

#### Scenario: Independent map widget configurations
- **WHEN** multiple map widgets exist across different flight screens
- **THEN** each map widget SHALL independently maintain its own terrain style, initial zoom level, orientation mode (e.g. Track Up vs North Up), and layer visibility toggles (airspaces, thermals, trail, contours)

#### Scenario: Per-widget zoom level configuration
- **WHEN** a pilot adjusts the zoom level in the map configuration dialog
- **THEN** the selected zoom level SHALL be persisted per widget and restored upon application restart

#### Scenario: Numeric widget style and label customization
- **WHEN** a pilot customizes a numeric instrument widget (such as Altitude, Speed, Glide, or HAG)
- **THEN** the widget SHALL display using its selected visual style (Minimalist, High Contrast, Circular Gauge, or Retro Digital), configured unit preference (`m` vs `ft` for Altitude/HAG, `km/h` vs `kt` vs `mph` for Speed), optional custom label override, and optional trend chevron indicator (`▲`/`▼`)

#### Scenario: Vario unit preference configuration
- **WHEN** a pilot configures a `varioBar` widget with a vertical speed unit preference (`m/s` or `fpm`)
- **THEN** the widget SHALL convert and format climb/sink and averager values in the selected unit (`1 m/s = 196.8504 fpm`, displayed in `m/s` or `fpm`) and persist the preference per widget placement

#### Scenario: Default style inheritance for new widgets
- **WHEN** a new widget is added to a screen from the widget picker
- **THEN** the widget SHALL instantiate with its built-in default style and configuration without requiring global fallback lookups

## ADDED Requirements

### Requirement: Live Rolling Glide Ratio Instrument
The `glide` cockpit instrument (`WidgetType.glide`) SHALL display a smoothed rolling glide ratio (L/D) computed over a 15-second integration window from horizontal groundspeed and vertical sink rate during both live telemetry and flight replay.

#### Scenario: Descending glide L/D calculation and clamping
- **WHEN** the aircraft is airborne (`meanSpeed >= 5.0 km/h`) and descending (`meanVario < -0.05 m/s`) in live flight or replay
- **THEN** the `glide` widget SHALL display the integrated ratio `-meanSpeedMps / meanVarioMs` formatted to one decimal place and clamped to `[0.5, 50.0]`

#### Scenario: Climbing glide state readout
- **WHEN** an active telemetry source or replay is present, the aircraft is airborne (`meanSpeed >= 5.0 km/h`), and the rolling vertical speed is climbing or level (`meanVario >= -0.05 m/s`)
- **THEN** the `glide` widget SHALL display `∞` instead of a static fallback number

#### Scenario: Stationary or pre-flight glide state readout
- **WHEN** an active telemetry source or replay reports groundspeed below `5.0 km/h`
- **THEN** the `glide` widget SHALL display `---`

### Requirement: Altitude Sparkline Climb/Sink Color Coding and Lookback Window
The `altitudeChart` instrument (`WidgetType.altitudeChart`) SHALL support color-coding the altitude profile by vertical climb/sink rate and configuring the historical time-window lookback per widget placement.

#### Scenario: Vario color-coded sparkline segments
- **WHEN** `altitudeChart` renders with vario color-coding enabled
- **THEN** ascending segments (`dh/dt > +0.2 m/s`) SHALL render in lift green, descending segments (`dh/dt < -0.2 m/s`) SHALL render in sink red/blue, and near-level segments SHALL render in the chart style's neutral accent color

#### Scenario: Configurable lookback time window
- **WHEN** the pilot selects an altitude chart lookback window (`2 min`, `10 min`, `30 min`, or `Full Flight`) in the widget configuration dialog
- **THEN** the chart SHALL slice the displayed altitude history to the selected duration and persist the setting in `WidgetPlacementModel`
