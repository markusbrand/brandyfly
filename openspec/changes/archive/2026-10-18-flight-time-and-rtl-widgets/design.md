# Design

## Context

BrandyFly's flight canvas renders instruments on a 16x32 virtual grid. Each widget placed on the canvas receives a `ValueListenable<CockpitTelemetry>`. Under the layered UI architecture (`layered-ui-architecture`), widgets do not subscribe to raw sensor streams or backend services directly; instead, they use `ValueSelector` in `WidgetSlot` to listen only to the specific scalar fields or rounded tuples they render.

Takeoff detection is executed in `FlightTrackingService` based on groundspeed, vario, and HAG triggers, retaining the full track in `_activeFlightPoints`. Flight replay is driven by `FlightReplayService`, which steps through recorded `FlightPoint` instances and exposes `elapsedDuration` and `currentPoint`. `TelemetryRepository` merges live sensor data, replay steps, and idle defaults into the unified `CockpitTelemetry` stream.

Currently, neither `CockpitTelemetry` nor the widget catalog provides flight timing or launch-relative navigation metrics. See `proposal.md` for motivation and `specs/` for behavioral requirements.

## Goals / Non-Goals

**Goals:**
- Provide real-time flight duration, takeoff timestamp, and local clock time cleanly through `CockpitTelemetry`.
- Provide return-to-launch (RTL) navigation metrics: horizontal distance (m/km), required glide ratio (L/D), altitude margin above launch ($\Delta h$), and bearing back to launch.
- Ensure 100% deterministic replay compatibility: replaying an IGC track must produce identical flight duration and RTL metrics as a live flight.
- Minimize battery and rendering overhead: quantize selector triggers to 1 Hz (or integer unit changes), avoiding UI redraws on 10-50 Hz sensor updates.
- Provide clear visual degradation: show standby modes before takeoff and explicit deficit indicators (`---`, negative altitude delta) when below launch altitude without arithmetic exceptions.

**Non-Goals:**
- Complex 3D digital elevation terrain clearance or wind-drifted glide cone pathfinding (RTL computes direct straight-line distance, bearing, and altitude delta relative to launch).
- Task/waypoint navigation (deferred to future XC competition navigation capability).
- Imperial/nautical unit configuration (handled in a separate change).

## Decisions

### Decision 1: Derive Launch Metrics in Telemetry Domain vs Widgets
- **Choice**: Compute launch-relative metrics (distance, bearing, required glide, altitude margin) and duration in the telemetry pipeline (`TelemetryRepository` / `CockpitTelemetry`) rather than inside the Flutter widget build methods.
- **Rationale**:
  - Keeps instrument widgets lightweight, pure, and testable without spatial geometry logic or service dependencies.
  - Ensures identical calculations for both live sensor streams and recorded IGC replay streams.
  - Allows future features (such as map RTL vector lines or thermal drift computations) to reuse the exact same telemetry state.
- **Alternatives Considered**:
  - *Compute in `ReturnGlideWidget.build`*: Would duplicate logic across replay and live modes, requiring widgets to depend on `FlightTrackingService` directly (breaking replay and testability).

### Decision 2: Geodesic Calculation Method
- **Choice**: Implement standard spherical Haversine formula for distance and forward azimuth formula for bearing:
  $$\Delta\sigma = 2 \arcsin \sqrt{\sin^2(\Delta\phi/2) + \cos\phi_1\cos\phi_2\sin^2(\Delta\lambda/2)}$$
  $$d = R \cdot \Delta\sigma$$
  $$\theta = \text{atan2}(\sin\Delta\lambda\cos\phi_2, \cos\phi_1\sin\phi_2 - \sin\phi_1\cos\phi_2\cos\Delta\lambda)$$
- **Rationale**: Computation time is negligible (< 1 µs), requires zero third-party dependencies, and yields sub-meter accuracy over typical paragliding distances (< 200 km).
- **Alternatives Considered**:
  - *Vincenty iterative geodesic*: Excessively complex with iteration termination risks for minimal gain at paragliding scale.
  - *Flat-earth equirectangular approximation*: Inaccurate at Alpine latitudes (45°-48° N) over 20+ km flights.

### Decision 3: Safety Guardrails for Glide Ratio
- **Choice**: When aircraft altitude is less than or equal to launch altitude ($\Delta h \le 0$) or distance to launch is less than 15 meters, set `requiredGlide` to `null` and render `---`. Display the negative altitude margin in warning accent color.
- **Rationale**: In paragliding, sinking below launch means return glide is physically impossible without thermaling. Emitting a negative glide ratio (e.g. `-14.2`) or dividing by zero is confusing and dangerous in the cockpit.
- **Alternatives Considered**:
  - *Show infinite glide or 99.9*: Misleading and risks pilot misinterpretation.

### Decision 4: Granular Subscription & Quantization in WidgetSlot
- **Choice**:
  - `flightTime`: Use `ValueSelector` on `(t.flightDuration?.inSeconds, t.hasSource)`.
  - `returnGlide`: Use `ValueSelector` selecting rounded display values:
    `(t.rtlDistanceMeters?.round(), (t.rtlRequiredGlide != null ? (t.rtlRequiredGlide! * 10).round() : null), t.rtlAltitudeMarginMeters?.round(), t.rtlBearingDegrees?.round())`.
- **Rationale**: High frequency (10-50 Hz) baro and IMU noise will not trigger widget rebuilds. Rebuilds only occur when displayed integers tick, preserving mobile battery life during long thermal flights.

## Risks / Trade-offs

- **[Risk] Pre-takeoff buffer prepending in FlightTrackingService can shift takeoff timestamp retroactively**
  - *Mitigation*: When takeoff is confirmed, `FlightTrackingService` uses `_preTakeoffBuffer.first.timestamp` as the official flight start. `TelemetryRepository` updates `takeoffTime` immediately upon the state transition, ensuring smooth elapsed duration calculation.
- **[Risk] GPS drift while waiting on launch could record an inaccurate takeoff point**
  - *Mitigation*: Takeoff location is locked when the takeoff heuristic triggers (sustained groundspeed/vario/HAG threshold), not upon app startup.
- **[Risk] Widget text overflow in tiny slots**
  - *Mitigation*: Follow the 3-tier convention (`tiny`, `compact`, `regular`). In tiny tier (< 40 dp), suppress labels and secondary metrics, displaying only the primary value.
