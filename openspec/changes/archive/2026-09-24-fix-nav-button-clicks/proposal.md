## Why

When the BrandyFly top navigation drawer is open, clicking on screen chips (especially the currently active screen chip) does not trigger any observable feedback or dismiss the drawer because Flutter's `ChoiceChip.onSelected` reports `false` on re-selection, which the current handler ignores. Furthermore, pointer events on buttons within the navigation drawer can be interfered with by micro-drags in enclosing scroll views or gesture competition with the underlying full-screen map canvas. This results in navigation buttons appearing unresponsive or broken to users clicking with a mouse or tapping on touchscreen devices.

## What Changes

- **ChoiceChip Re-selection & Direct Switching**: Fix `ChoiceChip.onSelected` in `TopNavBarOverlay` so that clicking any screen chip—whether newly selected or already active—properly updates or confirms the active screen and cleanly dismisses the navigation drawer.
- **Reliable Button Tap Registration**: Ensure all action buttons (`Flights`, `Edit Mode`, `Settings`, `Close`, and `Add Screen`) reliably trigger their action upon tap without being swallowed or canceled by parent drag gestures or enclosing scroll views.
- **Top Handle Hit-Testing & Accessibility**: Ensure the top grab handle has an unambiguous, hit-testable target area that reliably captures swipe-down and tap gestures over the full-screen map canvas.
- **Explicit Non-Goals**:
  - Replacing the gesture-driven hidden navigation bar architecture with a static top app bar is a non-goal (fullscreen edge-to-edge flight telemetry canvas must be preserved per `REQ-UI-003` / `REQ-UI-004`).
  - Redesigning the settings panel or flights screen is a non-goal.

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `screen-widget-configuration`: Update the `On-Demand Gesture-Driven Top Navigation Overlay` requirement to specify guaranteed click responsiveness for all drawer buttons, screen selector chips (including re-selection), and grab-handle hit testing.

## Impact

- **Affected Code**: `apps/mobile/lib/widgets/navigation/top_nav_bar.dart` and navigation overlay gesture bindings.
- **APIs & Dependencies**: Internal Flutter UI widget handling; no third-party dependency changes.
- **Safety & Offline Impact**: Pure UI/navigation layer; does not affect flight telemetry streaming, sensor loops, or offline PMTiles rendering.
