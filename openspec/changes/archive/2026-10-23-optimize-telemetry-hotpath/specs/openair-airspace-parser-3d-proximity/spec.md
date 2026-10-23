# Spec Delta

## MODIFIED Requirements

### Requirement: Airspace Side-Cut Profile Widget & Glide Slope Projection
The application SHALL render an interactive vertical cross-section side-cut profile widget displaying the aircraft position, projected forward glide path, terrain elevation profile, and intersecting airspace blocks along the current heading or track, using cached spatial queries to avoid synchronous ray-marching on every UI frame.

#### Scenario: Projecting glide slope against forward airspaces
- **WHEN** the aircraft is flying with groundspeed $> 0$ and current glide ratio $L/D = 8.5$
- **THEN** the side-cut widget calculates projected forward flight path $(x, z)$ up to a lookahead distance (e.g. 10 km)
- **AND** renders the linear glide slope line intersecting forward airspace floor/ceiling boundaries
- **AND** displays visual warning markers if the projected path enters a restricted or controlled airspace within the next 3 minutes of estimated flight time

#### Scenario: Rendering side-cut airspace blocks
- **WHEN** nearby airspaces exist along the forward track within the lookahead window
- **THEN** the side-cut widget renders rectangles / vertical cross-sections color-coded by airspace class (CTR, Prohibited, Danger, Restricted, Class A–E)
- **AND** displays labels with airspace name, class, floor, and ceiling

#### Scenario: Caching forward airspace ray-casting across minor telemetry ticks
- **WHEN** `getForwardAirspaces` is queried on consecutive telemetry ticks where horizontal displacement is $< 25\text{ m}$, heading change is $< 2^\circ$, altitude change is $< 10\text{ m}$, glide ratio change is $< 0.5$, and the loaded airspace set has not changed
- **THEN** `AirspaceService` SHALL return the cached list of `ForwardAirspaceBlock` instances without re-running polygon ray-marching.
