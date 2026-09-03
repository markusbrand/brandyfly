## Context

In paragliding flight computers, screen readability and full-viewport map coverage are crucial. Currently in `apps/mobile/lib/main.dart`, `_LiveFlightView` and `_MockFlightView` wrap `LayoutStrategyContainer` inside a `Scaffold` with an `AppBar` and a scrollable `ListView` containing static metadata cards (`_SectionCard`). This forces the active flight canvas into an arbitrary `380-520px` box, wasting more than half of the screen.

Furthermore, individual instrument widgets have large internal paddings (8–16px), fixed sub-box constraints (`SizedBox(width: 50, height: 120)`), and conservative font sizes, resulting in significant "dead space" around values and charts.

## Goals / Non-Goals

**Goals:**
- Render the flight screen (map + placed widgets) across 100% of the display viewport without static app bars, lists, or debug cards consuming layout space.
- Implement an on-demand, gesture-driven overlay architecture:
  - Top Navigation: Pull down via swipe-down gesture or tap on top grab handle.
  - Bottom Playback/Replay Controls: Collapsible bottom overlay, expandable via swipe-up gesture or tap on bottom grab handle.
  - Mock Session & Status: Streamlined floating overlay pill/chip that pilot can interact with or minimize.
- Overhaul widget sizing and inner padding:
  - Numeric widgets (`Altitude`, `Speed`, `Glide`, `HAG`) fill their frame with large typography and minimal margins.
  - `VarioLiftSinkBar` scales dynamically to fill container dimensions with clear climb/sink coloring.
  - `WindDirectionWidget` and `AltitudeSparklineChart` maximize graphical area.
  - `LayoutStrategyContainer` dynamically calculates cell dimensions and spans 100% of the viewport.

**Non-Goals:**
- Modifying underlying sensor math, telemetry calculation pipelines, or FAI IGC flight parsing logic.
- Modifying backend APIs or database schemas.

## Decisions

### 1. Fullscreen View Hierarchy in `main.dart`
- **Decision**: Replace `Scaffold` + `AppBar` + `ListView` in `_LiveFlightView` and `_MockFlightView` with a direct `Stack` containing the full-screen `LayoutStrategyContainer`, topped by gesture-driven overlay layers (`TopNavBarOverlay`, `ReplayControlOverlay`, floating mode chip/controls, and edit mode FABs).
- **Rationale**: Gives 100% of the display pixels to flight instrumentation while keeping navigation and controls instantly accessible on demand.

### 2. Gesture-Driven Navigation Overlays
- **Decision**:
  - `TopNavBarOverlay`: Uses vertical drag detection (swipe down from top edge `dy < 120` or drag on top grab handle) to smoothly slide down the navigation drawer with backdrop blur.
  - `ReplayControlOverlay`: Reworked with an animated slide/collapse controller and bottom grab handle so the user can swipe up to open full timeline controls or swipe down to collapse into a minimal bottom pill during flight replay.
- **Rationale**: Eliminates permanent UI obstruction during flight while preserving immediate, one-thumb access to all navigation and recorder features.

### 3. High-Density Widget Architecture
- **Decision**: Redesign internal widget builders (`NumericTextWidget`, `VarioLiftSinkBar`, `WindDirectionWidget`, `AltitudeSparklineChart`) to:
  - Reduce outer/inner padding from 8–16px down to 2–4px.
  - Use `FittedBox(fit: BoxFit.contain)` combined with full-width/height flex columns/rows so text digits and gauges expand to fill 95%+ of the bounding box.
  - Remove hardcoded inner `SizedBox` dimensions in favor of dynamic proportional layouts.
- **Rationale**: Ensures clear readability in bright sunlight and turbulent conditions without wasting display pixels on empty margins.

### 4. Dynamic Grid Scaling in `LayoutStrategyContainer`
- **Decision**: In `LayoutStrategyContainer`, dynamically compute `cellWidth = constraints.maxWidth / 4` and calculate grid cell heights to fill the entire container height (or expand when scrolling is needed for extra rows), ensuring seamless edge-to-edge alignment and zero gap for full-bleed map layers.
- **Rationale**: Guarantees consistent proportions across phone and tablet screens in both portrait and landscape modes.

## Risks / Trade-offs

- **[Risk] Touch conflict between map panning and pull-down/pull-up overlay gestures.**
  → **Mitigation**: Constrain gesture trigger zones to narrow top edge (top 32px or grab handle) and bottom edge (bottom 32px or grab handle), using `HitTestBehavior.translucent` so map panning in the center of the screen operates seamlessly.
- **[Risk] Existing widget tests expecting specific text elements or layouts.**
  → **Mitigation**: Update tests to verify the new fullscreen structure, interactive overlay gestures, and high-density widget layouts while preserving test coverage.

## Migration Plan

1. Rework `NumericTextWidget`, `VarioLiftSinkBar`, `WindDirectionWidget`, and `AltitudeSparklineChart` to remove dead space and maximize data density.
2. Update `LayoutStrategyContainer` to eliminate cell gaps and scale edge-to-edge across the full viewport.
3. Rework `ReplayControlOverlay` to support collapsible bottom overlay behavior with swipe-up/down gestures.
4. Refactor `_LiveFlightView` and `_MockFlightView` in `main.dart` to render full-screen edge-to-edge with pull-in navigation overlays and floating status pills.
5. Update and expand widget and unit tests to validate fullscreen behavior, swipe-to-reveal navigation, and widget rendering.
