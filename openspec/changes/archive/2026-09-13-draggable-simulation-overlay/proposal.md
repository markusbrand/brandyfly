## Why

In local mock flight mode (`BRANDYFLY_LOCAL_MOCK_FLIGHT_MODE=true`) and development testing, the mock session and playback controller overlay is pinned at a fixed position in the top-right corner (`top: 8, right: 8`). This overlay often obstructs critical top-right instrument widgets, top navigation triggers, or map interactions that developers and pilots need to inspect and interact with. Allowing pilots to freely drag and reposition the overlay anywhere on screen eliminates UI occlusion during flight simulation testing.

## What Changes

- Wrap the simulation overlay container in a pan-gesture drag detector allowing free-floating repositioning across the screen.
- Constrain dragging within the display viewport and safe area margins so the overlay cannot be moved off-screen.
- Retain the user-dragged position in memory across periodic telemetry ticks and manual scenario advances for the duration of the flight session.
- Automatically re-clamp the position within viewport bounds when expanding or minimizing the overlay to prevent edge clipping.
- Preserve discrete tap and hit-testing precedence for interactive child controls (advance scenario, reset replay, expand/minimize toggle buttons).

### Non-Goals
- Persisting the overlay position across full application restarts or in `SharedPreferences` (in-memory session state is sufficient).
- Snapping or magnetic docking to predefined screen corners or edges (free-floating placement gives maximum user control).
- Making other static badges (such as the live flight status chip) draggable.

## Capabilities

### New Capabilities
- `simulation-overlay-control`: Enables free-floating repositioning, viewport boundary clamping, and gesture disambiguation for the mock flight simulation controller overlay.

### Modified Capabilities
<!-- No existing capability requirements are changing -->

## Impact

- **Affected code**: `apps/mobile/lib/main.dart` (`_MockFlightView` and its overlay widget hierarchy) and corresponding widget tests in `apps/mobile/test/app_test.dart`.
- **APIs/Dependencies**: No new external dependencies or native bridge alterations; uses standard Flutter gestures and layout widgets (`GestureDetector`, `SafeArea`, `LayoutBuilder` / `MediaQuery`).
- **Privacy & Safety**: Simulation-only development mode; no user data is collected, transmitted, or affected. Safe flight core telemetry logic remains untouched.
- **Offline**: Fully functional offline; requires no network connectivity.
- **Licensing**: Fully compliant with the MIT license.
