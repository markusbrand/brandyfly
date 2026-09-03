## Context & Architecture

Paraglider pilots soaring in thermals experience significant horizontal drift due to ambient wind. When turning in circles, the ground track forms an asymmetric cycloid shape. To efficiently center the thermal lift core, the pilot needs to know:
1. When they have entered a sustained circling turn vs straight glide.
2. The ambient wind velocity and direction causing drift.
3. The true location of the maximum lift core inside the moving airmass.

```
                                  RUST FLIGHT CORE
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ Sensor Telemetry (GPS lat/lon/groundspeed/heading + Baro climb_rate_ms + timestamp_ms) │
└──────────────────────────────────────────┬─────────────────────────────────────────────┘
                                           │
                                           ▼
                 ┌──────────────────────────────────────────────────┐
                 │ HeadingTracker & CirclingStateDetector           │
                 │ - Sliding window heading delta integration       │
                 │ - Transitions: GLIDING <-> CIRCLING              │
                 └─────────────────────────┬────────────────────────┘
                                           │
                        ┌──────────────────┴──────────────────┐
                        ▼                                     ▼
      ┌────────────────────────────────────┐ ┌────────────────────────────────────┐
      │ WindEstimator                      │ │ ThermalCoreCalculator              │
      │ - 360° turn boundary detection     │ │ - Wind-drift coordinate transform  │
      │ - Inter-turn drift vector (Δx, Δy) │ │ - Lift-weighted centroid (w = c^2) │
      │ - Speed (km/h) & Direction (deg)   │ │ - Center of lift relative to pilot │
      └─────────────────┬──────────────────┘ └─────────────────┬──────────────────┘
                        └──────────────────┬───────────────────┘
                                           │
                                           ▼
                              ThermalStateSnapshot Event
                                           │
───────────────────────────────────────────┼──────────────────────────────────────────────
                                           ▼
                                FLUTTER MOBILE APP
                 ┌──────────────────────────────────────────────────┐
                 │ LayoutStrategyContainer & ScreenManagerService   │
                 │ - Ingests ThermalStateSnapshot & track history   │
                 └─────────────────────────┬────────────────────────┘
                                           │
                                           ▼
                 ┌──────────────────────────────────────────────────┐
                 │ ThermalMapWidget & ThermalCenteringPainter       │
                 │ - Climb rate colorized bubbles (Green/Orange/Red)│
                 │ - Sunlight-readable dark borders                 │
                 │ - Thermal core bullseye & drift vector arrow     │
                 │ - Airmass / Ground reference toggle              │
                 └──────────────────────────────────────────────────┘
```

## Mathematical Algorithms

### 1. Heading Tracking & Circling State Machine
Given discrete heading samples $\theta(t)$ and timestamps $t$:
- Normalize angular difference:
  $$\Delta \theta_k = ((\theta_k - \theta_{k-1} + 180^\circ) \bmod 360^\circ) - 180^\circ$$
- Heading rate $\omega_k = \frac{\Delta \theta_k}{\Delta t_k}$.
- In `GLIDING` mode:
  - Maintain running cumulative rotation angle $\Theta_{\text{turn}} = \sum \Delta \theta_k$ within a sliding 25.0s window.
  - If $|\Theta_{\text{turn}}| \ge 270^\circ$, transition immediately to `CIRCLING` mode with direction $\text{sgn}(\Theta_{\text{turn}})$.
- In `CIRCLING` mode:
  - Maintain heading stability counter: if $|\theta_k - \theta_{\text{base}}| \le 15^\circ$ continuously for $\ge 8.0\text{ seconds}$, transition back to `GLIDING`.

### 2. Wind Vector Estimation via Multi-Turn Drift
- Detect turn completions when cumulative heading change reaches integer multiples of $360^\circ$ ($2\pi$ radians).
- Let $P_{\text{turn}}(n)$ be the spatial position $(x_n, y_n)$ at turn index $n$ with timestamp $t_n$.
- For turn intervals $n \ge 2$:
  - Drift vector: $\vec{D} = P_{\text{turn}}(n) - P_{\text{turn}}(n-1)$.
  - Time elapsed: $\Delta T = t_n - t_{n-1}$.
  - Instantaneous turn wind: $\vec{V}_{\text{wind\_turn}} = \frac{\vec{D}}{\Delta T}$.
  - Meteorological wind direction:
    $$\text{Dir}_{\text{wind}} = ((\text{atan2}(-\vec{V}_{x}, -\vec{V}_{y}) \cdot \frac{180}{\pi} + 360) \bmod 360)^\circ$$
  - Wind speed: $\|\vec{V}_{\text{wind}}\| = \sqrt{V_x^2 + V_y^2}$.
- Filter successive turns using an exponential moving average ($\alpha = 0.6$).

### 3. Airmass Coordinate Transformation & Lift Core Centroid
- Transform ground coordinates $(x_{\text{gps}}, y_{\text{gps}})$ to airmass coordinates $(x_{\text{air}}, y_{\text{air}})$:
  $$\begin{pmatrix} x_{\text{air}}(t) \\ y_{\text{air}}(t) \end{pmatrix} = \begin{pmatrix} x_{\text{gps}}(t) \\ y_{\text{gps}}(t) \end{pmatrix} - \vec{V}_{\text{wind}} \cdot (t - t_0)$$
- Calculate lift weight $w_i = \max(0.0, c_i)^2$, where $c_i$ is the vario climb rate in m/s.
- Thermal core centroid $\vec{C}_{\text{core}}$:
  $$\vec{C}_{\text{core}} = \frac{\sum_{i=1}^N w_i \cdot \vec{P}_{\text{air}}(i)}{\sum_{i=1}^N w_i}$$
  (If $\sum w_i < \epsilon$, fallback to unweighted geometric center $\frac{1}{N}\sum \vec{P}_{\text{air}}(i)$).

## High-Contrast Visualizer Design (Flutter Canvas)

- **Bubble Colors & Sizing**:
  - $c > 1.5\text{ m/s}$: Emerald Green (`#00E676`), radius $12\text{px} \to 16\text{px}$, opacity $0.9$.
  - $0.2 < c \le 1.5\text{ m/s}$: Lime Green (`#76FF03`), radius $9\text{px} \to 12\text{px}$, opacity $0.8$.
  - $-0.5 \le c \le 0.2\text{ m/s}$: Warm Orange (`#FF9100`), radius $7\text{px} \to 9\text{px}$, opacity $0.65$.
  - $c < -0.5\text{ m/s}$: Bright Red (`#FF1744`), radius $6\text{px} \to 8\text{px}$, opacity $0.85$.
- **Contrast Border**: All bubble circles and glider icons render with a dark 1.2px outline (`Colors.black87` / `#1E293B`) ensuring legibility in direct sunlight against light map tiles.
- **Thermal Core Marker**: Concentric pulsing target bullseye rendered at $\vec{C}_{\text{core}}$ with a dashed line connecting glider position to core center for instant centering correction angle.
- **Wind Overlay**: Top-right / centered compass badge with aerodynamic wind vector arrow and numerical readout (e.g. `14 km/h SW`).

## Performance & Memory Budget

- Fixed-size ring buffer of 240 telemetry samples in Rust flight core ($\approx 2$ minutes at 2 Hz or 4 minutes at 1 Hz).
- Zero memory allocation in inner telemetry processing tick (`#![forbid(unsafe_code)]` compliant).
- Batch rendering in Flutter `CustomPainter` utilizing pre-allocated `Paint` objects and path reuse.

## Risks & Trade-offs

| Risk | Severity | Mitigation |
| :--- | :--- | :--- |
| GPS position jitter creating artificial wind drift | Medium | Apply minimum turn radius threshold (e.g. $r > 5\text{m}$) and discard turns with irregular geometry. |
| Inconsistent turn rates during thermaling | Low | Accumulate full $360^\circ$ heading integration rather than relying on constant time slices. |
| Low or zero wind conditions causing noisy wind directions | Low | If calculated wind speed $< 2.0\text{ km/h}$, mark wind direction as light/variable and disable airmass drift offset. |
