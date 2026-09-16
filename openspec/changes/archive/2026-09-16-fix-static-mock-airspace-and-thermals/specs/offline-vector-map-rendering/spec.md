## MODIFIED Requirements

### Requirement: Flight overlay preservation
The application SHALL render all existing flight overlays (airspace polygons, flight track, thermal markers, pilot marker, compass, HUD controls) on top of the MapLibre base map. Mock airspace restriction polygons and thermal updraft markers SHALL be anchored to static geographical coordinates on the map rather than following the pilot's position during flight.

#### Scenario: Overlay rendering on MapLibre
- **WHEN** the map is displayed during flight or replay
- **THEN** airspace polygons (CTR/TMA), GPS breadcrumb flight track (color-coded by climb rate), thermal updraft markers, pilot position marker with heading rotation, compass indicator, zoom controls, and scale bar are rendered correctly over the MapLibre vector tile base map

#### Scenario: Static geographic coordinates for mock airspace and thermals
- **WHEN** the pilot maneuvers or flies across the map
- **THEN** mock airspace restriction polygons and thermal updraft markers remain anchored at their fixed geographical positions on Earth, and do not translate with the glider's movement

#### Scenario: Overlay interaction unaffected
- **WHEN** the pilot interacts with zoom (+/-), recenter, or pans the map
- **THEN** overlays respond identically to the current flutter_map behavior (zoom steppers, auto-recenter toggle, pan-to-dismiss-center)
