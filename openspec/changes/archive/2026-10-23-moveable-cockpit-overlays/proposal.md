# Proposal

## Why

Currently, only the mock simulation controller overlay supports free-floating drag repositioning, while the Layout Edit Mode dock (`WidgetInspectorPanel` and `EditToolbar`), the `ReplayControlOverlay`, and the live flight recording/status overlay are fixed or only auto-flipped. In practice, the pinned bottom `EditToolbar` obscures bottom-row widgets (rows 28–32) even when the inspector flips to the top, `ReplayControlOverlay` permanently covers bottom-edge instruments during track playback, and the top-right live status pill is static and cannot be moved or used to monitor/control active flight recording. Making all cockpit overlays moveable, boundary-clamped, and collapsible gives pilots and layout authors unobstructed access to the entire 16x32 instrument canvas.

## What Changes

- **Shared Draggable Overlay Architecture (`DraggableOverlayContainer`)**:
  - Extract a reusable `DraggableOverlayContainer` widget that provides 2D pan-to-move repositioning, `MediaQuery` safe-area and viewport boundary clamping, automatic re-clamping on screen resize/rotation or expand/collapse state changes, and touch passthrough outside card bounds.
  - Refactor `_SimulationControlOverlay` to use `DraggableOverlayContainer` while preserving all existing keys, controls, and clamping behavior.
- **Moveable & Collapsible Live Recording Status Overlay (`RecordingStatusOverlay`)**:
  - Upgrade the static top-right status pill in `_LiveFlightView` into a free-draggable, collapsible `RecordingStatusOverlay` bound to `FlightTrackingService`.
  - Display live recording state (`STANDBY`, `REC <duration>`, or `LANDED`), mode badge (`LIVE` / `REPLAY`), platform status (`Running on: ...`), and a manual start/stop recording action button so pilots can manually trigger or finalize flight recording in addition to automatic takeoff/landing detection.
- **Moveable & Collapsible Replay Control Overlay (`ReplayControlOverlay`)**:
  - Make `ReplayControlOverlay` freely draggable across the viewport in both expanded and minimized states using 2D drag gestures, while preserving tap-to-collapse/expand on the grab handle and chevron button as well as timeline scrubbing and speed multiplier cycling (`1x`, `2x`, `5x`, `10x`).
- **Unified Moveable & Collapsible Edit Mode Dock**:
  - Combine `WidgetInspectorPanel` and `EditToolbar` into a unified Edit Mode dock that moves as a single unit.
  - Preserve smart auto-dodge positioning (docking to top, bottom, or side away from the selected widget) as the default behavior until the user manually drags the dock.
  - Allow free 2D dragging of the unified dock anywhere within the safe area, with a one-tap "Reset to Auto-Dodge" action when manually positioned, and a "Minimize/Expand" toggle that collapses the entire edit dock into a compact floating pill so the full 16x32 grid can be inspected unobstructed.

### Non-Goals

- Persisting temporary overlay drag coordinates across cold application restarts (session/in-memory persistence across telemetry ticks, screen switches, and expand/collapse toggles is sufficient and prevents off-screen confusion when switching devices).
- Changing the underlying 16x32 virtual grid coordinate math or widget placement schema in `UIConfig`.
- Modifying automatic takeoff/landing heuristic thresholds in `FlightTrackingService` (manual start/stop complements, rather than replaces, automatic detection).

## Capabilities

### New Capabilities

*None — all changes extend existing cockpit overlay, replay/recording, and layout editing capabilities.*

### Modified Capabilities

- `simulation-overlay-control`: Extend free-floating overlay repositioning, safe-area clamping, and child control interaction precedence to the shared draggable overlay container pattern.
- `flight-tracking-logbook-and-replay`: Add free-floating drag repositioning for `ReplayControlOverlay` and introduce the moveable `RecordingStatusOverlay` with live recording state display and manual start/stop recording controls.
- `screen-widget-configuration`: Update the Edit Mode inspector and toolbar into a unified, draggable, and collapsible Edit Dock that supports smart auto-dodge, manual drag override, auto-dodge reset, and compact pill minimization.

## Impact

- **Affected Code**:
  - `apps/mobile/lib/ui/core/widgets/draggable_overlay_container.dart` (new shared draggable container)
  - `apps/mobile/lib/widgets/flight/recording_status_overlay.dart` (new moveable live recording HUD)
  - `apps/mobile/lib/widgets/flight/replay_control_overlay.dart` (updated for 2D free-dragging + safe-area clamping)
  - `apps/mobile/lib/services/flight_tracking_service.dart` (add `startManualRecording()` and `stopManualRecording()` methods)
  - `apps/mobile/lib/ui/features/flight_canvas/views/layout_canvas.dart`, `apps/mobile/lib/ui/features/layout_editor/views/inspector_panel.dart`, and `apps/mobile/lib/ui/features/layout_editor/views/edit_toolbar.dart` (unified moveable and collapsible edit dock)
  - `apps/mobile/lib/main.dart` (wire `RecordingStatusOverlay`, `ReplayControlOverlay`, and refactored `_SimulationControlOverlay`)
- **Privacy, Safety, Offline & Licensing Impact**:
  - **Safety & Offline**: All overlay interactions and manual recording triggers operate 100% locally and offline on the UI layer without blocking the telemetry stream or audio vario isolate/loop. Moveable overlays improve flight safety by letting pilots uncover any obscured instrument immediately.
  - **Privacy**: No external network calls or telemetry changes.
  - **Licensing**: Pure Dart/Flutter UI and service logic under the repository's MIT license; zero new third-party dependencies.
