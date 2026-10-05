## MODIFIED Requirements

### Requirement: Flight overlay preservation
The application SHALL render all existing flight overlays (airspace polygons, flight track, pilot marker, compass, HUD controls) on top of the MapLibre base map. Thermal information SHALL be provided by the KK7 thermal heatmap layer (see `kk7-thermal-heatmap-layer`) instead of mock thermal updraft markers. Mock airspace restriction polygons SHALL be anchored to static geographical coordinates on the map rather than following the pilot's position during flight.

#### Scenario: Overlay rendering on MapLibre
- **WHEN** the map is displayed during flight or replay
- **THEN** airspace polygons (CTR/TMA), GPS breadcrumb flight track (color-coded by climb rate), pilot position marker with heading rotation, compass indicator, zoom controls, and scale bar are rendered correctly over the MapLibre vector tile base map

#### Scenario: No mock thermal markers
- **WHEN** the map is displayed with the thermal setting enabled or disabled
- **THEN** no hardcoded mock thermal updraft markers are drawn

#### Scenario: Static geographic coordinates for mock airspace and thermals
- **WHEN** the pilot maneuvers or flies across the map
- **THEN** mock airspace restriction polygons and the thermal heatmap remain anchored at their geographical positions on Earth, and do not translate with the glider's movement

#### Scenario: Overlay interaction unaffected
- **WHEN** the pilot interacts with zoom (+/-), recenter, or pans the map
- **THEN** overlays respond identically to the current flutter_map behavior (zoom steppers, auto-recenter toggle, pan-to-dismiss-center)

### Requirement: Licensing attribution
The application SHALL display proper attribution for OpenStreetMap data and Copernicus DEM data, and for thermal.kk7.ch data whenever the thermal heatmap is visible.

#### Scenario: Attribution visible on map
- **WHEN** the map is displayed
- **THEN** attribution text for OpenStreetMap contributors (ODbL) and Copernicus GLO-30 (CC-BY-4.0, ESA) is visible or accessible via an attribution button

#### Scenario: Thermal attribution visible
- **WHEN** the map is displayed with the thermal heatmap enabled
- **THEN** "Thermal map © thermal.kk7.ch, CC BY-NC-SA 4.0" is visible or accessible via the attribution button
