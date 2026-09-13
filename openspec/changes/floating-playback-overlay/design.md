## Context

Currently, `ReplayControlOverlay` in `apps/mobile/lib/widgets/flight/replay_control_overlay.dart` is rendered as a full-width bottom bar pinned to `bottom: 0, left: 0, right: 0` in `apps/mobile/lib/main.dart`.
In contrast, `_SimulationControlOverlay` in `main.dart` is wrapped in `Positioned.fill` and uses `LayoutBuilder`, `GestureDetector` (`onPanStart`, `onPanUpdate`), and dynamic viewport clamping to provide a free-floating draggable overlay.
Pilots reviewing recorded flights require the ability to reposition the replay HUD when it obstructs airspace boundaries, glide trails, or thermal assistant markers.

See `proposal.md` and `specs/flight-tracking-logbook-and-replay/spec.md` for motivation and requirements.

## Goals / Non-Goals

**Goals:**
- Provide free-floating 2D drag repositioning for `ReplayControlOverlay` across flight screens.
- Keep the overlay clamped within screen viewport boundaries and device safe areas (`MediaQuery.paddingOf(context)`).
- Provide a default bottom-anchored position that seamlessly initializes without jumping on first drag.
- Ensure the dragged position is ephemeral to the active replay session: closing and reopening replay resets position to default.
- Preserve touch responsiveness for child controls (timeline scrubber slider, play/pause, step buttons, speed cycle, close button).

**Non-Goals:**
- Persisting coordinates across app restarts or between distinct replay sessions.
- Modifying replay playback engine timing, telemetry interpolation, or IGC playback logic.
- Sharing state with or refactoring `_SimulationControlOverlay`.

## Decisions

### Decision 1: Encapsulate floating drag & boundary clamping within `ReplayControlOverlay`
- **Approach Chosen**: `ReplayControlOverlay` is mounted via `Positioned.fill` in `main.dart` when `isReplaying` is active. `ReplayControlOverlayState` maintains local state `Offset? _overlayPosition` and wraps its UI in a `LayoutBuilder` returning a `Stack` with `Positioned(left: clampedPos?.dx ?? defaultX, top: clampedPos?.dy ?? defaultY, child: card)`.
- **Alternative Considered**: Managing replay overlay position in `_MainFlightViewState` / `ScreenManagerService`.
  - *Rationale for Rejection*: State is strictly session-ephemeral and specific to the overlay widget. Exposing offset state in the screen manager or root state adds unnecessary coupling and ceremony.
- **Alternative Considered**: Using a 3rd party draggable overlay package.
  - *Rationale for Rejection*: BrandyFly avoids redundant dependencies. The pattern in `_SimulationControlOverlay` is already well-tested in Flutter, lightweight, and zero-cost.

### Decision 2: Default placement and smooth first-drag initialization
- **Approach Chosen**: When `_overlayPosition == null`, the overlay defaults to bottom-aligned (`top: constraints.maxHeight - cardHeight - safePadding.bottom - 8`, `left: (constraints.maxWidth - cardWidth) / 2`). On `onPanStart`, if `_overlayPosition == null`, the widget calculates its current `localToGlobal(Offset.zero)` and assigns it, ensuring smooth continuous panning with zero jump.
- **Alternative Considered**: Forcing an initial non-null offset in `initState`.
  - *Rationale for Rejection*: Initial screen constraints and safe area insets are not available until the first layout pass, and card dimensions depend on whether the overlay is initially expanded or collapsed.

### Decision 3: Card width constraint for floating aesthetic
- **Approach Chosen**: Constrain card width to `maxWidth: 420` (or `constraints.maxWidth - 24`), with centered default positioning.
- **Rationale**: Full-width pinned bars feel rigid, while a capped width card matches `_SimulationControlOverlay` and looks natural in both phone portrait and tablet landscape orientations.

### Decision 4: Gesture handling & touch precedence
- **Approach Chosen**: The outer card uses `GestureDetector(behavior: HitTestBehavior.opaque, onPanStart: ..., onPanUpdate: ...)`. Interactive child widgets (`IconButton`, `Slider`, `OutlinedButton`) consume horizontal/tap events in Flutter's gesture arena, preventing drag conflicts while allowing panning anywhere on the card background, padding, grab handle, and title row.
- **Alternative Considered**: Adding a separate dedicated drag handle icon.
  - *Rationale for Rejection*: The existing grab handle and card headers provide ample grab surface without cluttering the UI with additional icons.

## Risks / Trade-offs

- **[Risk] Gesture conflict between timeline Slider scrubbing and card drag panning**
  → *Mitigation*: The Flutter `Slider` widget recognizes and captures horizontal gestures during drag, winning gesture arena arbitration. Outer `GestureDetector` only receives unconsumed pans.
- **[Risk] Screen orientation changes (rotation) pushing overlay off-screen**
  → *Mitigation*: Boundary clamping executes on every build pass within `LayoutBuilder` against current `constraints.maxWidth` and `constraints.maxHeight`.
- **[Risk] Latency & battery impact during drag updates**
  → *Mitigation*: Drag updates only trigger local `setState` within `ReplayControlOverlayState`, updating a single transform/positioned offset without rebuilding parent screens or map rendering layers.
