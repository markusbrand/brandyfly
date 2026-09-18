## Context

BrandyFly renders real-time paragliding flight telemetry on an 8-column high-density custom layout, layered over MapLibre GL offline vector tiles with PMTiles local serving. Telemetry streams from either live sensors or simulated/replayed sources at up to 10Hz. As identified during autonomous emulator and static analysis runs:
1. Compact widget representations in edit mode (such as 1x1 or 2x1 grid cells) trigger `RenderFlex` horizontal overflows due to fixed-width headers and nudge control buttons.
2. The top navigation trigger handle is rendered at `top: 0` without safe area separation, colliding with the system status bar and causing touch detection failures on real devices and emulators.
3. Multiple custom painters (`MiniTrackPainter`, `VarioLiftSinkBar`, `AltitudeSparklineChart`) re-allocate paint resources and trigger unconstrained repaints without `RepaintBoundary` barriers.
4. The simulation control overlay defaults to overlapping primary flight data and retains trailing layout fragments when minimized.

## Goals / Non-Goals

**Goals:**
- Eliminate all `RenderFlex` overflows in `LayoutStrategyContainer` across all 1x1 to 8x16 widget placements.
- Ensure the top navigation grab handle and badges respect safe-area insets, providing a standard >=48x48dp accessible tap target with explicit `Semantics` descriptors.
- Maximize UI frame rates (target 60fps / 120fps with zero frame skipping) by adding `RepaintBoundary` nodes around high-frequency telemetry widgets, optimizing paint paths, and avoiding unnecessary point array copies in `MapWidget` and `ThermalMapWidget`.
- Ensure clean minimized state and boundary clamping for the simulation overlay.
- Prune unused code and refactor tightly coupled modules.
- Construct a comprehensive unit and widget test suite enabling test-driven development and safeguarding future changes.

**Non-Goals:**
- Modifying the underlying Rust flight core crate or native C FFI signatures.
- Modifying backend Raspberry Pi Go services.

## Decisions

### Decision 1: Adaptive Compact Headers & Fitted Toolbars in Edit Mode
- **Rationale**: In 8-column layout grids, a 1-column cell has a width of only ~40-60dp depending on screen size. The header row (`drag_indicator`, type title, config button, delete button) exceeds this available width.
- **Approach**: Wrap the header row in a `FittedBox(fit: BoxFit.scaleDown)` and dynamically hide the text title when cell width `w == 1`, prioritizing the drag indicator and delete/config actions. Apply `FittedBox` to the bottom stepper nudge bar as well.
- **Alternatives Considered**: Scrolling headers with `SingleChildScrollView` (rejected: interferes with drag gesture recognizers) or completely disabling edit mode for 1x1 widgets (rejected: breaks pilot customization flexibility).

### Decision 2: Safe-Area Compliant Top Navigation Trigger
- **Rationale**: System status bars (API 34+) reserve 24-48dp. Placing `top: 0` puts touch targets within Android's system gesture / notification shade zone.
- **Approach**: Anchor the navigation trigger using `SafeArea(top: true, bottom: false)` with an extended tap target of at least 48dp height, styled with a distinct pill indicator and full `Semantics(button: true, label: 'Open navigation and settings menu')`.
- **Alternatives Considered**: Fixed constant top padding of 32dp (rejected: varies by device and notch geometry).

### Decision 3: High-Frequency Telemetry Repaint Boundaries & Path Caching
- **Rationale**: GPS ticks arrive at 1-10Hz. In standard Flutter stacks, calling `setState()` high in the tree invalidates the entire screen canvas, causing `Choreographer` frame drops ("Skipped 48 frames!").
- **Approach**:
  - Wrap custom-painted widgets (`VarioLiftSinkBar`, `MiniTrackPainter`, `AltitudeSparklineChart`, `NumericTextWidget`) with `RepaintBoundary`.
  - In `MapWidget`, memoize the active track polyline list and only reconstruct coordinate buffers when coordinates actually change or exceed the history delta threshold.
- **Alternatives Considered**: Throttle telemetry to 0.5Hz (rejected: paragliding vario requires immediate response times; delayed vario is dangerous in active thermal flying).

### Decision 4: Simulation Overlay Polish and Non-Obstructive Default
- **Rationale**: When mock flight mode is active, the overlay currently defaults to top-right, obscuring the primary altitude display. Minimized state also showed clipped metadata.
- **Approach**: Completely omit secondary metadata when minimized, shrink container to a neat compact chip, and position it below the top instrument or allow free movement while remembering pilot preference.
- **Alternatives Considered**: Remove mock overlay entirely (rejected: critical for testing mock flight mode without external hardware).

### Decision 5: Dense Test-Driven Unit and Widget Test Suite
- **Rationale**: The existing 192 tests cover high-level flows, but lack dense edge-case testing for 1x1/1x2 layout overflows, boundary clamping maths, safe-area adaptations, paint path allocations, and error state transitions.
- **Approach**: Introduce comprehensive new unit test suites targeting layout constraint edge cases, accessibility semantics, telemetry latency, and widget rendering consistency.

## Risks / Trade-offs

- **[Risk]**: `FittedBox` scaling down icons excessively on 1x1 widgets could make them hard to tap.
  - **Mitigation**: Maintain minimum touch target size using `HitTestBehavior.translucent` padding and ensure `w >= 2` is recommended in presets.
- **[Risk]**: Repaint boundaries consume extra GPU memory layers.
  - **Mitigation**: Only apply `RepaintBoundary` to active telemetry instrument widgets that re-render frequently (vario, sparkline, numeric values), leaving static wrappers lightweight.
