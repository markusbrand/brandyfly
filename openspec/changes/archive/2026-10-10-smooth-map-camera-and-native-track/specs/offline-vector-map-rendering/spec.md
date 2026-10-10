## MODIFIED Requirements

### Requirement: Flight overlay preservation
The application SHALL render all existing flight overlays (airspace polygons, flight track, pilot marker, compass, HUD controls) with the MapLibre base map. The flight track and mock airspace polygons SHALL be rendered within the MapLibre render frame so they stay locked to the base map during camera motion; HUD elements (compass, controls, scale bar, badges) remain on top of the map. Thermal information SHALL be provided by the KK7 thermal heatmap layer (see `kk7-thermal-heatmap-layer`) instead of mock thermal updraft markers. Mock airspace restriction polygons SHALL be anchored to static geographical coordinates on the map rather than following the pilot's position during flight.

#### Scenario: Overlay rendering on MapLibre
- **WHEN** the map is displayed during flight or replay
- **THEN** airspace polygons (CTR/TMA), GPS breadcrumb flight track (color-coded by climb rate), pilot position marker with heading rotation, compass indicator, zoom controls, and scale bar are rendered correctly with the MapLibre vector tile base map

#### Scenario: Overlays locked to the base map
- **WHEN** the camera moves, rotates or zooms
- **THEN** the flight track and mock airspace polygon remain on the same geographic map features in every rendered frame

#### Scenario: No mock thermal markers
- **WHEN** the map is displayed with the thermal setting enabled or disabled
- **THEN** no hardcoded mock thermal updraft markers are drawn

#### Scenario: Static geographic coordinates for mock airspace and thermals
- **WHEN** the pilot maneuvers or flies across the map
- **THEN** mock airspace restriction polygons and the thermal heatmap remain anchored at their geographical positions on Earth, and do not translate with the glider's movement

#### Scenario: Overlay interaction unaffected
- **WHEN** the pilot interacts with zoom (+/-), recenter, or pans the map
- **THEN** overlays respond identically to the current flutter_map behavior (zoom steppers, auto-recenter toggle, pan-to-dismiss-center)

### Requirement: Low-Latency Telemetry and Vario Synchronization
The flight map and instrument widgets SHALL process high-frequency telemetry stream updates without causing main-thread frame skipping or UI render stalls, preserving immediate vario reactivity for paragliding navigation.

#### Scenario: Smooth marker and track updates during flight
- **WHEN** GPS telemetry ticks arrive at 1Hz to 10Hz frequencies during active flight or simulation
- **THEN** the pilot marker position and active track breadcrumbs SHALL update smoothly without triggering full map tile engine reloads or UI jank.
- **AND** the camera and pilot marker SHALL move continuously at display frame rate between ticks rather than stepping once per tick.

#### Scenario: Optimized custom painter caching
- **WHEN** custom telemetry painters (e.g. vario bar, sparklines, mini tracks) render successive frames
- **THEN** paint paths and stroke styles SHALL be reused or isolated via RepaintBoundaries to prevent unnecessary full-screen repaints.

#### Scenario: Long-flight frame budget
- **WHEN** a flight of 3 hours or more is displayed on the map
- **THEN** per-frame UI-thread work for the map SHALL NOT grow with the number of recorded track points
