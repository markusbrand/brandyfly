# Design

## Context

See `proposal.md` for background and user motivation.

Currently, `CockpitTelemetry` publishes instantaneous `climb` (m/s) and a `ThermalAssistantState` containing circling mode and wind estimates. `VarioLiftSinkBar` only consumes instantaneous climb. `CirclingStateDetector` accurately identifies circling sessions using a heading tracker window (`circlingThresholdDeg = 270.0`, `glidingStabilityDurationMs = 8000`).

To avoid taxing the hot sensor and audio vario loops, all rolling average calculations and thermal session aggregations must happen inside the telemetry processing layer and publish immutable snapshots to the UI canvas.

## Goals / Non-Goals

**Goals:**
- Provide a rolling climb average calculation (O(1) amortized or small ring buffer of at most 30 samples) without locking or GC pressure.
- Render a dual-indicator visualization on `VarioLiftSinkBar` (instant bar + averager needle + audio notches).
- Track thermal session lifecycle: start altitude, altitude gain, session average, duration, turns, and peak climb.
- Introduce `WidgetType.thermalStats` into the 16x32 grid widget catalog with full inspector, sizing, and layout support.
- Support seamless transitions between live circling and retained "LAST THERMAL" view during glide.

**Non-Goals:**
- Audio vario synthesis modification.
- Cloud synchronization or persistent database storage of individual thermals (flights logbook already records full IGC tracks).

## Decisions

### 1. Telemetry Snapshot Extension vs. Separate Streams
- **Decision**: Extend `CockpitTelemetry` with `averageClimb` and `thermalSession: ThermalSessionStats?` fields rather than introducing a separate broadcast stream.
- **Rationale**: The flight canvas and widget slots already subscribe to `CockpitTelemetry`. Bundling these values keeps UI rebuilds synchronized and eliminates stream coordination complexity.
- **Alternatives considered**:
  - *Direct polling from widget*: Violates unidirectional data flow and causes redundant calculations per widget instance.

### 2. Turn Count Estimation
- **Decision**: Compute turn count from the cumulative heading change tracked by the thermal assistant (`turns = (cumulativeHeadingDeg.abs() / 360.0).floor()`).
- **Rationale**: `HeadingTracker` already tracks unwrapped heading changes during circling; dividing by 360° gives an exact, physical turn count without adding extra GPS gyro algorithms.

### 3. Last Thermal Session Retention
- **Decision**: When `isCircling` drops to `false` (transition to straight glide), retain the latest completed `ThermalSessionStats` with `isLive: false` until a new circling session begins.
- **Rationale**: XC pilots need to evaluate the climb they just exited while transitioning and planning their next glide. Blanking the instrument upon exit frustrates pilots.

### 4. Vario Edge Bar Visual Layout
- **Decision**: Render the rolling average as a distinct horizontal needle marker with high-contrast accent color (amber/cyan) overlaid on the vertical bar track, alongside subtle tick marks at +0.2 m/s and -2.0 m/s.
- **Rationale**: Pilots can immediately compare instant lift with the rolling average at a glance without reading numbers.

```text
       [ +3.2 m/s ]  ø +1.8
      +-------------------+
      |         |         |
      |      [=====]      |  <-- Instant climb fill
      |         |         |
      |      >===== <     |  <-- 20s Averager needle
      |       - - -       |  <-- +0.2 m/s Audio threshold notch
      +=========0=========+  <-- Zero center line
      |       - - -       |  <-- -2.0 m/s Sink warning notch
      |                   |
      +-------------------+
```

## Risks / Trade-offs

- **[Risk] Rapid circling / reverse heading changes could create artificial thermal sessions**  
  → *Mitigation*: Rely on `CirclingStateDetector`, which requires 270° continuous turn before triggering `circling` and 8 seconds of stabilized heading before resetting to `gliding`.
- **[Risk] Screen clutter in tiny widget slots**  
  → *Mitigation*: Responsive size tiers: in `tiny` tier (< 40 dp), `thermalStats` renders only the net altitude gain (`+430m`); in `compact`, it renders gain + avg climb; in `regular` / `large`, it renders full 4-metric grid.
