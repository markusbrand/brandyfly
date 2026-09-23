## ADDED Requirements

### Requirement: Circling State Detection in Rust Core
The Rust flight core SHALL track glider heading changes and deterministically transition between `GLIDING` and `CIRCLING` flight states based on turn rate and heading stability.

#### Scenario: Triggering CIRCLING state upon 270-degree heading change
- **WHEN** the glider accumulates a cumulative heading change of $\ge 270^\circ$ in either clockwise or counter-clockwise direction within $\le 25.0$ seconds
- **THEN** the state detector SHALL transition the flight state to `CIRCLING`
- **AND** emit a state transition event with the turn direction (left or right) and timestamp.

#### Scenario: Triggering GLIDING state upon steady heading
- **WHEN** the glider is in the `CIRCLING` state
- **AND** the glider maintains a heading within $\pm 15.0^\circ$ of a baseline heading for $\ge 8.0$ seconds
- **THEN** the state detector SHALL transition the flight state to `GLIDING`
- **AND** reset the active thermal tracking buffer.

#### Scenario: Rejecting brief erratic heading reversals
- **WHEN** heading changes reverse direction without completing a consistent turn arc
- **THEN** the cumulative turn angle SHALL reset or decay, preventing false transitions to `CIRCLING` during straight-line turbulence.

### Requirement: Multi-Turn Wind Drift Estimation
The system SHALL calculate horizontal wind speed and direction vector from the positional drift across completed thermal turns.

#### Scenario: Estimating wind from 2 or more complete 360-degree turns
- **WHEN** the glider completes 2 or more full $360^\circ$ turns in the `CIRCLING` state
- **THEN** the wind estimator SHALL calculate the drift vector $(\Delta x, \Delta y)$ between turn centroids
- **AND** compute the horizontal wind speed ($\text{m/s}$ and $\text{km/h}$) and meteorological wind direction ($0^\circ \text{ to } 359^\circ$) by dividing drift displacement by total elapsed time across turns.

#### Scenario: Insufficient turn data for wind estimation
- **WHEN** fewer than 2 complete $360^\circ$ turns have been recorded in the current thermaling session
- **THEN** the wind estimator SHALL mark the wind estimate as uncalculated or invalid
- **AND** the system SHALL fallback to zero drift or previously retained valid wind vector without throwing errors.

#### Scenario: Continual wind vector refinement
- **WHEN** additional complete turns are recorded during continuous circling
- **THEN** the wind estimator SHALL update the rolling wind drift vector using an exponential or weighted moving average of the latest turns.

### Requirement: Thermal Core Centroid and Airmass Transformation
The flight core SHALL calculate the lift-weighted center of gravity of the thermal and transform GPS coordinates into a wind-corrected airmass frame.

#### Scenario: Transforming track points into wind-corrected airmass coordinates
- **WHEN** a valid wind vector $\vec{V}_{\text{wind}}$ is available
- **THEN** each track point $P_{\text{gps}}(t)$ SHALL be transformed into an airmass position $P_{\text{air}}(t) = P_{\text{gps}}(t) - \vec{V}_{\text{wind}} \cdot (t - t_0)$
- **AND** the resulting airmass track SHALL cancel the horizontal drift cycloid into a centered circular loop.

#### Scenario: Computing lift-weighted center of gravity
- **WHEN** track points with climb rates are recorded in the active thermaling session
- **THEN** the core calculator SHALL compute the thermal center as the weighted centroid:
  $$\vec{C}_{\text{core}} = \frac{\sum w_i \cdot \vec{P}_i}{\sum w_i}, \quad w_i = \max(0, v_z(i))^2$$
- **AND** emit the coordinates of $\vec{C}_{\text{core}}$ relative to the pilot's current position.

#### Scenario: Zero or negative climb handling
- **WHEN** all points in the window have climb rate $\le 0\text{ m/s}$ (pure sink)
- **THEN** the thermal core calculator SHALL fallback to the geometric center of the turn circle without division by zero.

### Requirement: High-Contrast Thermal Centering Visualizer Widget
The mobile application SHALL render an XCtrack-grade thermal assistant canvas displaying colorized bubble tracks, thermal core center, and wind vector.

#### Scenario: High-contrast climb rate colorization
- **WHEN** track points are rendered on the thermal assistant canvas
- **THEN** points SHALL be colorized using high-contrast bands:
  - Strong climb ($> +1.5\text{ m/s}$): Bright Green
  - Moderate climb ($+0.2\text{ to }+1.5\text{ m/s}$): Light Green / Lime
  - Neutral / Weak sink ($-0.5\text{ to }+0.2\text{ m/s}$): Orange
  - Strong sink ($< -0.5\text{ m/s}$): Vivid Red
- **AND** each bubble SHALL render with a dark 1px outline for sunlight legibility over maps and light backgrounds.

#### Scenario: Displaying estimated thermal core and wind direction
- **WHEN** the thermal core center and wind vector are provided by telemetry
- **THEN** the widget SHALL display an animated pulsing bullseye marker at the estimated core center
- **AND** SHALL display a wind vector arrow pointing in the wind direction along with a numeric wind speed badge.

#### Scenario: Coordinate display mode selection
- **WHEN** the pilot configures the thermal visualizer mode
- **THEN** the widget SHALL support displaying either ground track coordinates with wind drift or wind-compensated airmass coordinates centered on the thermal core.
