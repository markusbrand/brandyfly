## MODIFIED Requirements

### Requirement: Lift and sink rate colorized flight track
The map visualization engine SHALL render the active flight track using segmented continuous color gradients that reflect the climb/sink vertical speed ($v_z$) of each recorded segment.

#### Scenario: Visualizing climbing flight in a thermal
- **WHEN** the aircraft records flight points with vertical speed $v_z \ge +0.5\text{ m/s}$
- **THEN** the corresponding track segments SHALL be colored in green tones, continuously interpolating from light pale green (`#86EFAC`) at $+0.5\text{ m/s}$ to vibrant green (`#22C55E`) at $+1.5\text{ m/s}$ up to dark emerald green (`#15803D`) at $+3.5\text{ m/s}$ and above.

#### Scenario: Visualizing gliding flight in neutral air
- **WHEN** the aircraft records flight points with vertical speed between $-0.5\text{ m/s}$ and $+0.5\text{ m/s}$
- **THEN** the corresponding track segments SHALL be colored in neutral slate grey (`#94A3B8`).

#### Scenario: Visualizing sinking flight in downdrafts or polar glide
- **WHEN** the aircraft records flight points with vertical speed $v_z \le -0.5\text{ m/s}$
- **THEN** the corresponding track segments SHALL be colored in red tones, continuously interpolating from light pale coral (`#FCA5A5`) at $-0.5\text{ m/s}$ to medium red (`#EF4444`) at $-1.5\text{ m/s}$ down to deep dark red (`#991B1B`) at $-3.0\text{ m/s}$ and below.

#### Scenario: Track history time window filtering
- **WHEN** the flight duration exceeds the configured history duration (default: 10 minutes)
- **THEN** the high-contrast colored gradient SHALL be applied exclusively to points recorded within the active history window $[t_{\text{current}} - T_{\text{window}}, t_{\text{current}}]$.

#### Scenario: Faded baseline for historical track
- **WHEN** `mapTrackShowOlderTail` is enabled and points exist older than $T_{\text{window}}$
- **THEN** the older historical path SHALL be rendered as a muted, thin neutral trail behind the active gradient track.

---
