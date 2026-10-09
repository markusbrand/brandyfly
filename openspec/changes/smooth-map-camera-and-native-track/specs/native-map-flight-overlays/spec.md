## Purpose

Renders the flight track, mock airspace and pilot marker inside the MapLibre render frame so they stay locked to the base map during camera motion, with bounded per-update cost on long flights.

## ADDED Requirements

### Requirement: Map-synchronous flight overlays
The flight track and the mock airspace polygon SHALL be rendered as part of the map's own rendering, so they remain geographically locked to the base map on every frame, including during camera motion, rotation and zoom.

#### Scenario: No overlay swim during follow
- **WHEN** the center-locked camera moves and rotates continuously during flight
- **THEN** track vertices and airspace edges stay on the same geographic map features in every frame, with no visible offset relative to the base map

#### Scenario: Pinch and pan gestures
- **WHEN** the pilot pans or zooms the map
- **THEN** the track and airspace move together with the base map without lagging a frame behind

### Requirement: Pilot marker presentation
The pilot marker SHALL be shown at the displayed (smoothed) pilot position with heading rotation: anchored at the camera's pilot anchor point while center-locked, and at its geographic position on the map while the pilot pans freely.

#### Scenario: Center-locked marker
- **WHEN** the map is center-locked
- **THEN** the marker is drawn at the pilot anchor point (true center in north-up, 50 % width / 60 % from top in track-up) without jitter

#### Scenario: Free pan marker
- **WHEN** center-lock is released by panning
- **THEN** the marker stays at the pilot's geographic position on the map and keeps moving as new fixes arrive

#### Scenario: Marker rotation
- **WHEN** orientation is north-up
- **THEN** the marker rotates to the filtered heading
- **AND** in track-up the marker points straight up

### Requirement: Track history window and older tail
The rendered track SHALL apply the configured history window (`mapTrackHistoryMinutes`, 0 = full flight): points within the window are drawn with the vario color gradient, and when `mapTrackShowOlderTail` is enabled older points are drawn as a muted thin neutral trail; when it is disabled older points are not drawn.

#### Scenario: Window applied
- **WHEN** the flight is 30 minutes long and the history window is 10 minutes
- **THEN** only the last 10 minutes are drawn with the vario gradient

#### Scenario: Older tail enabled
- **WHEN** the older tail is enabled
- **THEN** the remaining 20 minutes are drawn as a muted thin neutral trail beneath the gradient track

#### Scenario: Older tail disabled
- **WHEN** the older tail is disabled
- **THEN** points older than the window are not drawn

### Requirement: Bounded overlay update cost
Appending a new fix to the displayed track SHALL cost work proportional to the recently added points, not to the full flight length, and SHALL NOT perform per-point screen projection on the UI thread.

#### Scenario: Long flight
- **WHEN** a 3-hour flight with 1 Hz fixes (≈10,800 points) is displayed and a new fix arrives
- **THEN** only the recent-track data is resent to the map for that fix, and full track data is rebuilt no more often than every 10 seconds

#### Scenario: No per-point projection
- **WHEN** the map renders a frame during flight
- **THEN** no per-track-point geographic-to-screen projection is performed by the app

### Requirement: Scoped map rebuilds
A telemetry tick SHALL NOT rebuild the whole map widget subtree; only the motion state and HUD elements whose displayed values changed SHALL update.

#### Scenario: 10 Hz telemetry
- **WHEN** telemetry arrives at 10 Hz and only position changes
- **THEN** the map widget, style and controls are not rebuilt, and the altitude/speed HUD text rebuilds only when its rounded displayed value changes

#### Scenario: Replay tick
- **WHEN** replay advances by one point
- **THEN** the replay pipeline does not copy the entire track history for that tick

### Requirement: Overlay availability and failure behavior
Overlays SHALL appear once the map style has loaded, SHALL survive style reloads (e.g. region change), and a failure to update native overlay data SHALL NOT interrupt the map or telemetry.

#### Scenario: Style reload
- **WHEN** the map style is reloaded after a region change
- **THEN** the track, airspace and marker layers are re-added with the current data

#### Scenario: Overlay update failure
- **WHEN** a native overlay update fails
- **THEN** the error is logged, the previous overlay state remains visible, and the next update retries with current data
