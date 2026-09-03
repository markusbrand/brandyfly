## Purpose

Provides a customizable Thermal Assistant map widget for the thermaling screen displaying flight trail circles colored by lift (green) and sink (red) with dynamic transparency scaling, layered above the background map and beneath HUD instrument widgets.

## ADDED Requirements

### Requirement: Thermal Map Widget Type
The application SHALL support a `thermalMap` widget type within `WidgetType` that can be placed, sized, moved, and customized within the grid layout system.

#### Scenario: Adding thermal map via widget picker
- **WHEN** the user opens the Widget Picker sheet and selects "Thermal Map"
- **THEN** a `thermalMap` widget is added to the active screen's layout.

#### Scenario: Persisting thermal map widget configuration
- **WHEN** the screen configuration is serialized to JSON and deserialized back
- **THEN** all `thermalMap` properties (position, size, style, zoom level) are preserved.

### Requirement: Default Thermaling Screen Configuration
The default `thermaling` screen configuration SHALL include a `thermalMap` widget sized to cover the entire default grid (width: 4, height: 4) positioned at (0, 0), with instrument widgets positioned as overlays.

#### Scenario: Initial launch or reset to defaults
- **WHEN** the user activates or resets the `thermaling` screen to default configuration
- **THEN** the screen displays the `thermalMap` across the full background grid with overlay widgets (such as vario bar, wind, and altitude) on top.

### Requirement: Widget Layer Ordering
The screen layout strategy SHALL sort and render widgets in a specific vertical stack hierarchy:
1. Base terrain map widgets (`WidgetType.map`) on the bottom layer.
2. Thermal map widgets (`WidgetType.thermalMap`) directly above the base terrain map.
3. All other instrument widgets (numeric texts, vario bar, wind direction, altitude chart) in the foreground above both map layers.

#### Scenario: Rendering screen with base map, thermal map, and instrument widgets
- **WHEN** a screen contains a base map, a thermal map, and one or more numeric instrument widgets
- **THEN** the base map is rendered at layer 0, the thermal map at layer 1, and the numeric instruments at layer 2+.

### Requirement: Lift and Sink Circles Visualization
The thermal map widget SHALL render circling flight track points as colored circular markers indicating instantaneous or smoothed vario climb rates:
- Positive climb rate (lift) SHALL be rendered in green hue (`#00E676` / `#4CAF50`).
- Negative climb rate (sink) SHALL be rendered in red hue (`#FF1744` / `#F44336`).
- Neutral climb rate (0.0 m/s) SHALL be rendered as a neutral dot or transition point.
- Color opacity (alpha transparency) SHALL scale proportionally with the magnitude of lift/sink:
  - Strong lift (>= +3.0 m/s) and strong sink (<= -2.5 m/s) SHALL render at full opacity (1.0).
  - Weak lift (+0.1 to +0.5 m/s) and weak sink (-0.1 to -0.5 m/s) SHALL render with light transparency (0.25 to 0.40).
  - Intermediate values SHALL interpolate smoothly between the minimum and maximum opacity.

#### Scenario: Visualizing strong thermal lift
- **WHEN** the glider circles through a strong core of +3.5 m/s
- **THEN** the thermal map renders vivid, high-opacity green circles along that track segment.

#### Scenario: Visualizing sink encountered during circling
- **WHEN** the glider exits the core into a sink area of -1.5 m/s
- **THEN** the thermal map renders semi-transparent red circles along that track segment.

### Requirement: Reference UI Style Presets
The thermal map widget SHALL provide selectable visual style presets (`ThermalMapStyle`):
1. `xctrackBubbles`: Scaled bubble trail with time-decay fading and turn-tracking radius.
2. `burnairCore`: Bubble trail combined with an estimated thermal core marker and wind drift vector.
3. `navigatorRibbon`: Continuous color-graded thermal ribbon with distinct lift/sink bubble milestones.
4. `flyskyhyRadial`: High-contrast radial dots with outer stroke for terrain readability.

#### Scenario: User switches thermal map style
- **WHEN** the user selects a different `ThermalMapStyle` in the widget settings sheet
- **THEN** the thermal map immediately re-renders using the visual presentation of the selected preset.
