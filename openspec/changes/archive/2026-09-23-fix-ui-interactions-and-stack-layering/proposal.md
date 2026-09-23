## Why

Recent UI hardening and accessibility improvements inadvertently introduced gestures and gesture detectors that block or cancel taps and gestures in other parts of the application. 
- The `TopNavBarOverlay` grab handle is still rendered when navigating to the Settings screen, where its unbounded vertical hit area overlaps the Settings "Close" button. 
- The `FlightReplayService` emits `notifyListeners()` on every tick, which forces the `AnimatedBuilder` that wraps `MaterialApp` to rebuild the entire widget tree up to 10-60 times a second during replay or simulation. This constant reconstruction of `MaterialApp` kills any in-progress gesture arenas (taps or drags) in `TopNavBarOverlay` or `_SimulationControlOverlay` (the Mock Flight Session control bar).

## What Changes

- Update `TopNavBarOverlay` to avoid rendering the grab handle when `isSettingsVisible` is true.
- Refactor the `AnimatedBuilder` in `apps/mobile/lib/main.dart` to NOT wrap the `MaterialApp` entirely. We will instead push the `AnimatedBuilder` down to the specific `_LiveFlightView` and `_MockFlightView` (and overlays) that actually need to react to `_replayService` ticks, preserving the `MaterialApp` state so active gestures are not aborted mid-stream.
- Ensure the Mock Flight Session overlay correctly initiates drags using absolute global coordinates instead of being anchored incorrectly upon pan start.

## Capabilities

### New Capabilities
None

### Modified Capabilities
None (pure bugfix)

## Impact

- `apps/mobile/lib/main.dart` (Move `AnimatedBuilder` down to leaf flight views).
- `apps/mobile/lib/widgets/navigation/top_nav_bar.dart` (Hide grab handle in Settings).
