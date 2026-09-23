## Context

The main application screen renders the entire `MaterialApp` widget, but historically it has been wrapped in an `AnimatedBuilder` that listens to BOTH `ScreenManagerService` and `FlightReplayService`. Because `FlightReplayService` emits notifications on every 16ms to 50ms tick during a mock flight or replay, it forces Flutter to destroy and rebuild the entire `MaterialApp`.
This continuous destruction and recreation of `MaterialApp` terminates active `GestureRecognizer` arenas mid-gesture. This prevents any taps, vertical drags, or pan gestures from ever completing if they span across a timer tick. This effectively renders `TopNavBarOverlay`, `ReplayControlOverlay`, and `_SimulationControlOverlay` completely unclickable and undraggable.
Additionally, the new `SafeArea` grab handle for the top navigation bar inadvertently overlaps the Settings screen Close button because it doesn't verify if Settings is currently visible.

## Goals / Non-Goals

**Goals:**
- Stop `MaterialApp` from rebuilding continuously during flight simulation or replay.
- Ensure all click and pan gestures complete smoothly and independently from underlying telemetry ticks.
- Unblock the Settings Close button.

**Non-Goals:**
- Completely redesigning `TopNavBarOverlay` or its gesture recognizers.
- Rebuilding `FlightReplayService` (it is fine for it to tick to notify UI widgets, as long as it doesn't rebuild the entire app).

## Decisions

1. **Decoupling MaterialApp from FlightReplayService tick rebuilds**:
   Instead of wrapping `MaterialApp` in an `AnimatedBuilder(Listenable.merge([_screenManager, _replayService]))`, we will only use `_screenManager` for the top-level app rebuilds (since screen changes are rare). The `_replayService` will only be fed into local `AnimatedBuilder`s inside specific widgets that need to update their UI based on the tick (like `ReplayControlOverlay`, `_MockFlightView`, and `_SimulationControlOverlay`).
   *Alternative*: Debounce the replay service `notifyListeners`. *Trade-off*: Replay playback requires smooth high-frequency ticks to move the map. The UI must rebuild to animate the replay, but ONLY the relevant parts of the UI. Rebuilding `MaterialApp` was an anti-pattern.

2. **TopNavBarOverlay visibility condition**:
   Update `!widget.screenManager.isNavBarVisible && !widget.screenManager.isEditMode` to include `&& !widget.screenManager.isSettingsVisible` for rendering the `top_nav_grab_handle`.

## Risks / Trade-offs

- [Risk] Some deeper child widgets might have relied on `MaterialApp` rebuilding to get fresh data from `FlightReplayService`.
  → Mitigation: The specific sub-widgets like `_MockFlightView` or `_SimulationControlOverlay` are already observing the service or we will wrap them individually in `AnimatedBuilder` if needed. `ReplayControlOverlay` is already wrapped in its own `AnimatedBuilder(animation: widget.replayService)`.
