## MODIFIED Requirements

### Requirement: Temporary Pan and Inactivity Auto-Recenter Timer
The application SHALL permit temporary manual panning of the map and automatically restore center-lock after 6 seconds of user inactivity.

#### Scenario: User pans the map
- **WHEN** the pilot drags/pans either `MapWidget` or `ThermalMapWidget`
- **THEN** center-lock is temporarily disengaged, the map camera moves across geographic coordinates following the drag gesture, and an inactivity timer of 6 seconds is started/reset.
- **AND** the pilot position marker, flight track breadcrumbs, airspace polygons, and thermal overlays in `MapWidget` stay anchored to their respective earth coordinates rather than translating across a static base map.

#### Scenario: Inactivity timeout triggers auto-recenter
- **WHEN** 6 seconds elapse without any further pan/drag touch events
- **THEN** the map automatically recenters on the pilot's current position and restores center-locked tracking.

#### Scenario: Manual recenter button tap
- **WHEN** the pilot taps the HUD "Recenter" button before the timer expires
- **THEN** the inactivity timer is cancelled, and the map immediately snaps back to center-locked tracking.
