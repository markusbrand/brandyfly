## Purpose

Provides a high-visibility, ergonomic, and customizable flight cockpit interface designed for paragliding pilots under direct sunlight and high-vibration cockpit environments.

## ADDED Requirements

### Requirement: Modern Cockpit Theme & Visual Design Tokens
The application SHALL render instrument views using high-contrast design tokens optimized for outdoor glare, including dark cockpit mode with vibrant accent accents, blur-glass telemetry cards, and dynamic climb/sink color coding (green for climb, red for sink).

#### Scenario: Visual rendering in dark cockpit mode
- **WHEN** the user opens the cockpit telemetry view
- **THEN** the interface SHALL apply high-contrast dark cockpit tokens with distinct climb (+m/s green) and sink (-m/s red) indicators.

### Requirement: Dynamic Animated Vario Instrument Gauge
The application SHALL provide a dynamic vario gauge widget that displays real-time vertical speed with high-visibility radial arc sweeps, digital numeric telemetry, and smooth micro-animations.

#### Scenario: Real-time vario arc indicator update
- **WHEN** vertical speed telemetry updates during flight simulation or live flight
- **THEN** the vario gauge SHALL smoothly animate the sweep arc and update numeric telemetry values.

### Requirement: Multi-Layout Cockpit View Switching
The application SHALL support switching between dedicated cockpit dashboard layouts tailored for specific flight phases: Thermal/Climb View, Cruise/XC View, and Split Mounted View.

#### Scenario: User switches to Cruise View
- **WHEN** the pilot selects the Cruise view mode from the cockpit navigation bar
- **THEN** the dashboard SHALL transition layout focus to ground speed, glide ratio, and altitude history profile.

#### Scenario: User switches to Thermal View
- **WHEN** the pilot selects the Thermal view mode from the cockpit navigation bar
- **THEN** the dashboard SHALL focus layout on vertical speed, climb rate history, and thermal core gradient indicators.

### Requirement: Adaptive Responsive Layouts & Glove-Friendly Interaction
The application SHALL adapt telemetry element arrangements for portrait and landscape orientations on mobile phones and flight-deck tablets, maintaining a minimum touch target size of 48dp for all interactive flight controls.

#### Scenario: Mobile orientation change
- **WHEN** the mobile display rotates between portrait and landscape mode
- **THEN** the dashboard SHALL re-lay out instrument tiles in a side-by-side or stacked grid without clipping telemetry values.

#### Scenario: Cockpit touch interaction
- **WHEN** interactive controls (mode switches, scenario triggers, view selectors) are displayed
- **THEN** touch targets SHALL measure at least 48x48 density-independent pixels with clear visual focus/elevation states.
