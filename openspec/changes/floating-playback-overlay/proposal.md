## Why

During flight replay, the playback control overlay currently sits pinned across the bottom of the screen. This fixed placement can obscure critical flight path details, thermal markers, airspace boundaries, or underlying instrument widgets that a pilot or analyst needs to inspect. Making the playback overlay free-floating—mirroring the behavior of the simulation overlay—enables users to drag the controls to any convenient part of the screen during playback while keeping the default location clean upon starting new replay sessions.

## What Changes

- Convert `ReplayControlOverlay` into a free-floating, draggable overlay on the flight screens similar to `_SimulationControlOverlay`.
- Support real-time drag-and-drop repositioning with boundary clamping against display viewport edges and system safe areas.
- Keep overlay position ephemeral for the active replay session without persisting position to disk; restarting replay or entering a new replay session resets to the default placement.
- Maintain seamless touch precedence so tapping playback buttons (play/pause, seek slider, speed multiplier, exit, minimize/expand) functions reliably without triggering unintentional drag events.

### Non-Goals
- Persisting playback overlay coordinates across app restarts or across distinct flight replay sessions.
- Unifying or merging the flight replay overlay codebase with the debug `_SimulationControlOverlay`.
- Changing replay telemetry parsing, playback timing, or flight track rendering logic.

## Capabilities

### New Capabilities
<!-- None -->

### Modified Capabilities
- `flight-tracking-logbook-and-replay`: Update the playback control overlay requirement from a fixed bottom bar to a free-floating, repositionable HUD with boundary clamping and session-scoped position retention.

## Impact

- **Affected Code**: `apps/mobile/lib/widgets/flight/replay_control_overlay.dart`, `apps/mobile/lib/main.dart` (and any related widget test suites).
- **APIs & Dependencies**: Pure Flutter UI change; no external dependency additions.
- **Safety**: Improves situational inspection during replay analysis by avoiding occlusion of critical map telemetry and airspace lines.
- **Privacy & Offline**: Fully local-first and offline-capable. No data collected or transmitted.
- **Licensing**: MIT compliant.
