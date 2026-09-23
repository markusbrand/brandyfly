## 1. Fix TopNavBarOverlay Grab Handle

- [x] 1.1 In `apps/mobile/lib/widgets/navigation/top_nav_bar.dart`, add `!widget.screenManager.isSettingsVisible` to the rendering condition of the `top_nav_grab_handle` to prevent it from overlapping the Settings Close button. Verify by visually inspecting the code or running flutter tests.

## 2. Refactor MaterialApp Rebuild

- [x] 2.1 In `apps/mobile/lib/main.dart`, change the top-level `AnimatedBuilder` to only listen to `_screenManager` instead of `Listenable.merge([_screenManager, _replayService])`. Verify by ensuring `MaterialApp` is returned directly from the `AnimatedBuilder` that listens only to `_screenManager`.
- [x] 2.2 In `apps/mobile/lib/main.dart`, wrap `_MockFlightView` in an `AnimatedBuilder` that listens to `_replayService` if it doesn't already, so that it rebuilds correctly during simulation ticks. Verify by confirming that mock flight progresses correctly when the slider advances.

## 3. Fix Mock Session Position Bug

- [x] 3.1 In `apps/mobile/lib/main.dart` inside `_SimulationControlOverlayState.build()`, update `onPanUpdate` to properly initialize `currentPos` if `_overlayPosition` is null. It currently initializes using `safePadding.top + 8` instead of `safePadding.top + 56`. Verify by confirming that the fallback `y` matches the initial build `y`.
