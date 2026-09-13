## Context

See `proposal.md` for motivation. Currently, in `apps/mobile/lib/main.dart`, `_MockFlightView` renders inside a full-screen `Scaffold` containing a `Stack`. The simulated flight overlay is fixed via:
```dart
Positioned(
  top: 8,
  right: 8,
  child: SafeArea(...),
)
```
The view rebuilds every 2 seconds due to `_timer.periodic` advancing the mock flight scenario, as well as on manual advance/reset actions.

## Goals / Non-Goals

**Goals:**
- Provide smooth, free-floating pan repositioning across the screen.
- Maintain accurate viewport and `SafeArea` boundaries to prevent the overlay from clipping or escaping the visible screen.
- Retain the dragged coordinates during the entire flight session across scenario updates and rebuilds.
- Ensure buttons (`IconButton` for advance, reset, minimize/expand) trigger cleanly on tap without triggering drags.

**Non-Goals:**
- Edge snapping or magnetic corners (free-floating placement gives the pilot full control).
- Storing overlay position across full application cold restarts in persistent disk storage (`SharedPreferences`).

## Decisions

### Decision 1: Free-Floating Translation via `GestureDetector` over `Draggable`
- **Choice**: Use a `GestureDetector` on the overlay card with `onPanUpdate` tracking coordinate offsets directly in `_MockFlightViewState`, rendered via `Positioned(left: pos.dx, top: pos.dy)`.
- **Rationale**: Flutter's `Draggable` widget is designed for data transfer between drop targets and clones the widget into an overlay feedback layer during dragging, which complicates live timer updates and transient widget state. A direct pan gesture with `Offset` state in `_MockFlightViewState` has zero allocation overhead, zero flicker, and updates at 60/120 FPS.
- **Alternatives Considered**:
  - `Draggable` / `DragTarget`: Dropped due to unnecessary feedback avatar overhead and state disconnection.
  - Predefined snap grid: Dropped because pilots need fine-grained control to avoid blocking specific instrument cells.

### Decision 2: Viewport-Aware Clamping & Default Placement
- **Choice**: Wrap the overlay placement in a `LayoutBuilder` inside the `Stack` to obtain exact `constraints.maxWidth` and `constraints.maxHeight`, combined with `MediaQuery.paddingOf(context)`.
- **Logic**:
  - When `_overlayPosition` is uninitialized (`null`), default to top-right: `x = maxWidth - overlayWidth - safePadding.right - 8`, `y = safePadding.top + 8`.
  - During `onPanUpdate`, add delta: `newPos = currentPos + details.delta`.
  - Clamp `x` between `safePadding.left + 4` and `maxWidth - overlayWidth - safePadding.right - 4`.
  - Clamp `y` between `safePadding.top + 4` and `maxHeight - overlayHeight - safePadding.bottom - 4`.
  - When switching between minimized and expanded states (`_isSessionMinimized`), clamp the existing position against the updated height.

### Decision 3: Gesture Disambiguation
- **Choice**: Rely on Flutter's standard gesture arena where child `IconButton` buttons take precedence for vertical/horizontal tap recognizers, while `onPanUpdate` on the parent container only engages once touch movement exceeds the slop threshold.
- **Rationale**: Users can comfortably tap "Next", "Reset", or "Minimize" without accidentally moving the card.

## Risks / Trade-offs

- **[Risk] Device rotation / window resize pushing position off-screen**
  - **Mitigation**: During `build()`, clamp the stored `Offset` against the current `BoxConstraints` and `MediaQuery` padding before positioning the widget.
- **[Risk] Sizing discrepancy when expanding near bottom edge**
  - **Mitigation**: Constrain card `maxWidth` (360 dp) and provide a safe height estimate/clamping boundary check when `_isSessionMinimized` toggles.
