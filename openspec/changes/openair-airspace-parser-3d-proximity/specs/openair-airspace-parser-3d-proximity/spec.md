## ADDED Requirements

### Requirement: OpenAir Airspace File Parsing & Geometry Construction
The system SHALL parse OpenAir format definitions (.txt, .openair) into structured in-memory airspace entities supporting standard records (`AC`, `AN`, `AH`, `AL`, `DP`, `DC`, `DA`, `DB`, `V`, `SP`, `SB`) and convert all circular and arc segments into closed planar polygons.

#### Scenario: Parsing standard polygonal airspace
- **WHEN** an OpenAir file containing airspace class `AC R`, name `AN ED-R107`, floor `AL 1000ft AGL`, ceiling `AH FL 100`, and polygon points `DP 47:30:00 N 013:00:00 E ...` is parsed
- **THEN** the parser creates an Airspace entity with Class `Restricted`, Name `ED-R107`, Floor `1000ft AGL`, Ceiling `FL 100`, and a closed polygon ring with the parsed coordinates
- **AND** records are parsed deterministically without throwing unhandled exceptions on comments or whitespace

#### Scenario: Parsing circular and arc airspace zones
- **WHEN** an OpenAir definition includes a center point `V X=47.5 Y=13.2` and circle radius `DC 5.0` (or arc `DA 5.0, 90, 270` or `DB ...`)
- **THEN** the parser discretizes the circle or arc into a sequence of polygonal vertices with chord distance tolerance $\le 10\text{ m}$
- **AND** produces a valid closed bounding polygon ring for spatial indexing

#### Scenario: Handling malformed records and comments
- **WHEN** the input stream contains comment lines starting with `*`, unrecognized records, or blank lines
- **THEN** the parser skips non-structural lines gracefully
- **AND** records structural parse warnings without aborting valid preceding or subsequent airspace blocks

---

### Requirement: Spatial R-Tree Indexing and 2D Proximity Computation
The flight core SHALL maintain an in-memory 2D R-Tree spatial index of all loaded airspace polygons, allowing sub-millisecond bounding box queries and exact horizontal separation distance calculations.

#### Scenario: Querying nearby airspaces for aircraft position
- **WHEN** the aircraft position $(lat, lon)$ is evaluated during a telemetry cycle
- **THEN** the system performs an R-Tree bounding box lookup within a configurable candidate radius (default 15 km)
- **AND** returns candidate airspaces ordered by closest 2D Euclidean distance to the polygon boundary

#### Scenario: Point-in-polygon classification
- **WHEN** the aircraft horizontal position is inside the boundary coordinates of an airspace polygon
- **THEN** the horizontal separation distance is computed as $0\text{ m}$
- **AND** the state indicates `InsideHorizontalBoundary`

---

### Requirement: QNH and Reference-Aware Vertical Altitude Conversion
The system SHALL dynamically evaluate vertical floor and ceiling limits for candidate airspaces, converting Flight Level (FL), Mean Sea Level (MSL), Above Ground Level (AGL), and Ground/Surface (GND/SFC) references to absolute meters MSL based on active QNH pressure settings and terrain ground elevation.

#### Scenario: Flight Level conversion under non-standard QNH
- **WHEN** an airspace ceiling is defined as `FL 100` and the current QNH setting is $1023\text{ hPa}$ (standard pressure $1013.25\text{ hPa}$)
- **THEN** the system calculates the absolute MSL altitude in meters by applying standard barometric pressure offset $(1023 - 1013.25) \times 8.43\text{ m} \approx +82.3\text{ m}$
- **AND** computes absolute ceiling altitude as $(100 \times 100 \times 0.3048) + 82.3 = 3130.3\text{ m MSL}$

#### Scenario: AGL conversion with terrain elevation model
- **WHEN** an airspace floor is defined as `1500ft AGL` and the terrain elevation beneath the aircraft is $1200\text{ m MSL}$
- **THEN** the system resolves the absolute floor altitude as $1200 + (1500 \times 0.3048) = 1657.2\text{ m MSL}$

#### Scenario: Fixed MSL and Ground floor conversion
- **WHEN** an airspace floor is `GND` or `SFC` and ceiling is `5000ft MSL`
- **THEN** the floor altitude is evaluated as terrain ground elevation (or $0\text{ m MSL}$ if terrain is unavailable)
- **AND** the ceiling altitude is evaluated as $5000 \times 0.3048 = 1524.0\text{ m MSL}$

---

### Requirement: 3D Proximity Detection & 3-Tier Alert System
The system SHALL continuously evaluate 3D proximity between the aircraft and all candidate airspaces, triggering tiered warnings with debounced hysteresis transitions.

#### Scenario: Level 1 (Advisory) proximity trigger
- **WHEN** the horizontal separation to an active airspace boundary is $< 1000\text{ m}$ OR the vertical separation to its floor/ceiling is $< 150\text{ m}$ (and not already in Warning or Violation state)
- **THEN** the system emits a `Level 1 Advisory` state for the airspace
- **AND** surfaces the airspace name, class, and separation distance

#### Scenario: Level 2 (Warning) proximity trigger
- **WHEN** the horizontal separation is $< 500\text{ m}$ OR the vertical separation is $< 75\text{ m}$
- **THEN** the system transitions the alert state to `Level 2 Warning`
- **AND** emits high-priority audio/visual alert events to the UI

#### Scenario: Level 3 (Violation) proximity trigger
- **WHEN** the aircraft is horizontally inside the airspace polygon AND aircraft altitude is between floor and ceiling ($floor \le altitude_{MSL} \le ceiling$)
- **THEN** the system immediately transitions the alert state to `Level 3 Violation`
- **AND** logs a timestamped airspace entry event in the flight telemetry stream

#### Scenario: Alert clearance with hysteresis
- **WHEN** the aircraft departs an airspace boundary and separation exceeds the trigger threshold by more than $10\%$ (e.g. horizontal separation $> 550\text{ m}$ for Warning or $> 1100\text{ m}$ for Advisory) for at least 2 consecutive seconds
- **THEN** the alert state safely downgrades or clears without flickering

---

### Requirement: Airspace Side-Cut Profile Widget & Glide Slope Projection
The application SHALL render an interactive vertical cross-section side-cut profile widget displaying the aircraft position, projected forward glide path, terrain elevation profile, and intersecting airspace blocks along the current heading or track.

#### Scenario: Projecting glide slope against forward airspaces
- **WHEN** the aircraft is flying with groundspeed $> 0$ and current glide ratio $L/D = 8.5$
- **THEN** the side-cut widget calculates projected forward flight path $(x, z)$ up to a lookahead distance (e.g. 10 km)
- **AND** renders the linear glide slope line intersecting forward airspace floor/ceiling boundaries
- **AND** displays visual warning markers if the projected path enters a restricted or controlled airspace within the next 3 minutes of estimated flight time

#### Scenario: Rendering side-cut airspace blocks
- **WHEN** nearby airspaces exist along the forward track within the lookahead window
- **THEN** the side-cut widget renders rectangles / vertical cross-sections color-coded by airspace class (CTR, Prohibited, Danger, Restricted, Class A–E)
- **AND** displays labels with airspace name, class, floor, and ceiling
