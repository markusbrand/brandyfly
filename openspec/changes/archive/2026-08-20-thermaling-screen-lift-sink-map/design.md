## Context

Paragliders rely on thermal lift to stay airborne and gain altitude. When a pilot enters a thermal, they perform 360-degree turns to stay within the rising air column. Because thermals are invisible and drift with the ambient wind, pilots need a real-time visualization showing where lift and sink were encountered during recent turns.

Popular instruments handle this in distinctive ways:
- **XCtrack**: Uses a dynamic bubble trail where circle size and color saturation scale with climb rate, fading older turns over time.
- **Burnair Go / Navigator**: Uses colored breadcrumb circles and calculates an estimated "thermal core center" to help pilots recenter their circle.
- **Flyskyhy**: Uses high-contrast colored radial dots with crisp borders over topo terrain.

In BrandyFly's modular grid architecture, widgets are positioned in a 4-column coordinate grid and rendered inside `LayoutStrategyContainer`. Currently, the base `map` widget is sorted to layer 0. We need to introduce `thermalMap` on layer 1, keeping HUD instrument widgets (altimeter, speed, vario bar, wind arrow) on layer 2+.

## Goals / Non-Goals

**Goals:**
- Implement `WidgetType.thermalMap` as a first-class customizable widget.
- Implement high-performance custom canvas rendering (`ThermalMapPainter`) for lift/sink circles with dynamic opacity and color interpolation.
- Establish robust 3-tier layering in `LayoutStrategyContainer`: `map` (0) -> `thermalMap` (1) -> `instruments` (2).
- Configure the default `thermaling` screen to place `thermalMap` at (0, 0, 4, 4) behind the instruments.
- Provide 4 distinct UI style options representing paragliding app conventions (XCtrack, Burnair Go, Navigator, Flyskyhy).

**Non-Goals:**
- Global thermal database / crowd-sourced thermals server (scoped for future release).
- Acoustic audio tone synthesis modifications (handled by vario audio service).

## UI Design Proposals (For User Selection)

### Proposal 1: XCtrack Bubble Trail (Dynamic Radius & Alpha Decay)
- **Visual Design**: Circular bubble points plotted every 1.5–2.0 seconds along the circling path.
- **Coloring**: 
  - Lift: Bright Green (`#00E676`), opacity $20\% \to 100\%$ scaling with climb $+0.2 \to +3.5\text{ m/s}$. Radius scales dynamically from $6\text{px}$ to $14\text{px}$.
  - Sink: Vibrant Red (`#FF1744`), opacity $20\% \to 100\%$ scaling with sink $-0.2 \to -3.0\text{ m/s}$.
- **Trail Decay**: Points older than 90 seconds gradually fade out to keep the display clean.
- **Glider Indicator**: Central heading arrow with turn rate arc.
- **Pros**: Highly intuitive, proven standard among XC competition pilots.

### Proposal 2: Burnair Thermal Core Assist (Bubbles + Estimated Lift Center)
- **Visual Design**: Colored lift (green) and sink (red) circles plus an algorithmic **Thermal Core Center marker** (concentric dashed pulsing circle) calculated from the weighted centroid of the strongest lift points.
- **Wind Drift Vector**: Draws an arrow indicating wind drift direction to anticipate core displacement with altitude.
- **Pros**: Actively guides the pilot on where to shift the turn circle to center the core.

### Proposal 3: Navigator Heat Ribbon (Continuous Graduated Band)
- **Visual Design**: Continuous smooth spline ribbon connecting track points with color-gradient interpolation (deep red $\to$ yellow $\to$ vivid emerald green) overlaid with discrete peak lift/sink bubble badges.
- **Readout Overlay**: Mini-pill displaying average climb per 360° turn (+1.8 m/s avg, +65m gain).
- **Pros**: Very clean look, easy to see the full spiral geometry.

### Proposal 4: FlySkyHy Clean Radial Dots (High-Contrast Outlined Dots)
- **Visual Design**: Crisp circular discs with a dark 1px outline for extreme sunlight readability against any map terrain background (topo, satellite, or dark mode).
- **Coloring**: Discrete 5-tier color palette (Dark Green, Light Green, Neutral Grey, Light Red, Dark Red).
- **Pros**: Maximum legibility in harsh bright sunlight and over detailed map layers.

## Technical Decisions

1. **Widget Layer Ordering in `LayoutStrategyContainer`**:
   - Update `_getOrderedWidgets` to assign layer indices:
     - Base Map (`WidgetType.map`): `0`
     - Thermal Map (`WidgetType.thermalMap`): `1`
     - Instrument HUD widgets: `2`
   - This ensures thermal circles render over terrain/satellite maps but never obscure vital numeric flight data.

2. **Data Pipeline & Mock Integration**:
   - The widget consumes track history points containing `(latitude, longitude, altitude, climbRateMs, timestamp)` or local relative coordinates `(dx, dy, climbRateMs)`.
   - In local mock flight mode (`BRANDYFLY_LOCAL_MOCK_FLIGHT_MODE`), mock circling flight path with realistic climb/sink variations will be generated.

3. **Config & Persistence Model**:
   - Add `thermalMapStyle` property to `WidgetPlacementModel` with enum `ThermalMapStyle { xctrackBubbles, burnairCore, navigatorRibbon, flyskyhyRadial }`.
   - Add `thermalMapShowCore` and `thermalMapHistorySeconds` configuration parameters.

## Risks / Trade-offs

- **Risk**: Performance degradation when rendering hundreds of trail points on lower-end mobile devices.
  - **Mitigation**: Ring-buffer point storage capped at 120 points (last 2 minutes) with `CustomPainter` batch canvas operations (`drawPoints` / `drawCircle` with pre-cached `Paint` objects).
- **Risk**: Overlap confusion if both Base Map and Thermal Map are active.
  - **Mitigation**: Thermal map canvas uses transparent background so base map contours and terrain show through naturally underneath the lift/sink circles.
