# Design

## Context

See `proposal.md` for motivation and scope. Currently in `apps/mobile`:
- `_SimulationControlOverlay` (`apps/mobile/lib/main.dart`) implements custom `LayoutBuilder` + `GlobalKey` + `onPanStart`/`onPanUpdate` coordinate math with safe-area clamping, while other overlays cannot be moved.
- `_LiveFlightView` (`apps/mobile/lib/main.dart`) renders a static `Positioned(top: 8, right: 8)` status pill that is not wired to `FlightTrackingService`.
- `ReplayControlOverlay` (`apps/mobile/lib/widgets/flight/replay_control_overlay.dart`) is pinned inside `Positioned(bottom: 0, left: 0, right: 0)` in `main.dart` and uses `onVerticalDragUpdate` to toggle expansion, preventing 2D drag movement and permanently covering bottom-row widgets during flight replay.
- `_buildEditDock` (`apps/mobile/lib/ui/features/flight_canvas/views/layout_canvas.dart`) splits `WidgetInspectorPanel` and `EditToolbar` on portrait screens when the selected widget is in the lower half (`inspectorOnTop == true`), leaving `EditToolbar` pinned to `bottom: 8` where it still covers bottom-row widgets, and offers no way to drag or collapse the edit chrome when inspecting full-screen (`16x32`) widgets.

## Goals / Non-Goals

**Goals:**
- Provide a single, deterministic `DraggableOverlayContainer` widget for 2D free-floating overlays with viewport + safe-area clamping and zero touch interception outside the overlay card bounds.
- Make `RecordingStatusOverlay`, `ReplayControlOverlay`, `_SimulationControlOverlay`, and the unified Edit Mode Dock smoothly moveable and collapsible without regressions to existing tests or telemetry performance.
- Support manual flight recording start/stop from `RecordingStatusOverlay` via `FlightTrackingService`.

**Non-Goals:**
- Persisting temporary overlay drag positions to disk (`SharedPreferences`) across app restarts.
- Modifying the 16x32 grid layout engine math or widget serialization format.

## Decisions

### 1. Shared `DraggableOverlayContainer` Widget vs. Per-Overlay Drag Logic
- **Decision**: Introduce `DraggableOverlayContainer` in `apps/mobile/lib/ui/core/widgets/draggable_overlay_container.dart`.
- **How it works**:
  - Uses a `LayoutBuilder` to obtain parent viewport `constraints` and `MediaQuery.paddingOf(context)` for safe-area insets.
  - Accepts either an initial alignment/anchor callback (or default `top`/`bottom`/`left`/`right` anchor) when `_position == null`, or an external/internal `Offset?` when dragged.
  - Measures the child card's `RenderBox` via a `GlobalKey` on `onPanStart` / `onPanUpdate` and during layout clamping so that even when the child changes size (e.g., expanding/collapsing `ReplayControlOverlay`, `_SimulationControlOverlay`, or the Edit Dock), its `(dx, dy)` is clamped to `[safePadding.left + margin, maxWidth - cardWidth - safePadding.right - margin]` and `[safePadding.top + margin, maxHeight - cardHeight - safePadding.bottom - margin]`.
  - Wraps only the positioned card in a `GestureDetector(behavior: HitTestBehavior.opaque, onPanStart: ..., onPanUpdate: ...)` inside a non-intercepting `Stack`, ensuring all touches outside the card pass through to underlying map and cockpit widgets.
- **Alternatives Considered**:
  - *Duplicating `_SimulationControlOverlay`'s `onPanUpdate` logic in 4 widgets*: Rejected because edge-clamping on expand/collapse and safe-area handling would be duplicated in four places and drift over time.
  - *Using Flutter's `Draggable` / `OverlayEntry`*: Rejected because `Draggable` creates a separate drag avatar rather than moving the live interactive widget in place, and `Stack` + `Positioned` within the existing view hierarchy is simpler and more deterministic in widget tests.

### 2. `ReplayControlOverlay` Gesture Disambiguation (2D Drag vs. Expand/Collapse)
- **Decision**: Replace `onVerticalDragUpdate` expand/collapse on `ReplayControlOverlay` with 2D free-drag (`onPanUpdate`) via `DraggableOverlayContainer`, while keeping tap-to-toggle on `Key('replay_bottom_grab_handle')` and `Key('btn_replay_collapse')` / `Key('btn_replay_expand')`.
- **Rationale**: Previously, `onVerticalDragUpdate` on the entire card intercepted vertical drags to toggle `_isExpanded`, making it impossible to drag the replay bar vertically up the screen. By using `onPanUpdate` on the card background/header to move the card in 2D and tap on the grab handle or chevron button to collapse/expand, both interactions are conflict-free. Existing Slider scrubbing continues to win the horizontal gesture arena because Flutter's `Slider` registers its own horizontal drag recognizer inside the child tree.
- **Latency & GPU Trade-off**: Keep the card width constrained (e.g. `maxWidth: 460` or viewport width minus margins) so it floats cleanly anywhere on phones and tablets without spanning 100% of a tablet's width when dragged.

### 3. `RecordingStatusOverlay` and Manual Start/Stop in `FlightTrackingService`
- **Decision**:
  - Add `startManualRecording({DateTime? now})` and `stopManualRecording({DateTime? now})` to `FlightTrackingService`.
    - `startManualRecording`: When in `FlightState.groundPreflight`, transitions immediately to `FlightState.flying`, copies `_preTakeoffBuffer` into `_activeFlightPoints`, emits `FlightState.flying` on `_stateController`, and calls `notifyListeners()`.
    - `stopManualRecording`: When in `FlightState.flying`, calls `_finalizeFlight(now ?? (_activeFlightPoints.isNotEmpty ? _activeFlightPoints.last.timestamp : DateTime.now().toUtc()))` to finalize the flight, generate IGC/stats, emit on `_flightCompletedController`, and transition to `FlightState.landed`.
  - Create `RecordingStatusOverlay` (`apps/mobile/lib/widgets/flight/recording_status_overlay.dart`) wrapped in `DraggableOverlayContainer` (defaulting to top-right below safe area).
  - Listens only to `FlightTrackingService.stateStream` (and a 1 Hz timer or point timestamps while `FlightState.flying`) so it does not rebuild the entire screen on every sensor tick.
  - Preserves the `BrandyFly` title, `LIVE`/`REPLAY` mode chip, and `Running on: $platformVersion` detail (collapsible via a minimize/expand toggle) alongside the recording badge (`STANDBY`, `REC mm:ss`, `LANDED`) and manual start/stop icon button (`Key('btn_manual_record_toggle')`).

### 4. Unified Moveable & Collapsible Edit Mode Dock
- **Decision**:
  - Unify `WidgetInspectorPanel` and `EditToolbar` inside a single dock container in `LayoutCanvas` (`_EditDockOverlay`).
  - **Smart Auto-Dodge Default**: When `_manualDockOffset == null` (the default upon entering Edit Mode), the unified dock (both `WidgetInspectorPanel` and `EditToolbar`, with `WidgetInspectorPanel` above `EditToolbar`) positions itself away from the selected widget:
    - On wide canvases (`outerSize.width > outerSize.height && outerSize.width >= kSideDockMinWidth`): docks to the left or right side opposite `selectedCenter.dx`.
    - On tall canvases: docks at the bottom (`bottom: 8`) when `selectedCenter == null || selectedCenter.dy <= outerSize.height / 2`, and flips the **entire unified dock** (both `WidgetInspectorPanel` and `EditToolbar`) to the top (`top: 8`) when `selectedCenter.dy > outerSize.height / 2`.
  - **Manual Drag Override**: Dragging the Edit Dock drag bar (`Key('edit_dock_drag_handle')`) or dock background updates `_manualDockOffset`, switching the dock into free-floating clamped mode at `(dx, dy)`.
  - **Auto-Dodge Reset & Minimize Controls**:
    - The Edit Dock header bar includes a minimize/expand toggle (`Key('btn_edit_dock_minimize')`) that collapses the dock into a compact pill (`EditingLayout` + `Add Widget` + `Expand` + `Done`) and, when `_manualDockOffset != null`, a reset-to-auto-dodge button (`Key('btn_edit_dock_auto_dodge')`) that clears `_manualDockOffset`.
    - Exiting Edit Mode resets `_manualDockOffset = null` and `_isEditDockMinimized = false`.

## Risks / Trade-offs

- **[Risk] Gesture arena conflict between `Slider` / buttons and `DraggableOverlayContainer` pan recognizer** → **Mitigation**: Flutter's gesture arena naturally gives precedence to inner `IconButton`/`FilledButton` tap recognizers and `Slider` horizontal drag recognizers over an ancestor `GestureDetector.onPanUpdate`. We will verify this with dedicated widget tests tapping buttons and scrubbing the replay slider inside the draggable overlays.
- **[Risk] Existing layout tests check `Key('edit_toolbar')` and `Key('widget_inspector_panel')` positions** → **Mitigation**: Preserve `Key('edit_toolbar')` and `Key('widget_inspector_panel')` and ensure `WidgetInspectorPanel` remains above `EditToolbar` (`panel.bottom <= toolbarTop`) in both bottom-docked and top-docked auto-dodge positions so all existing assertions in `apps/mobile/test/ui/flight_canvas_test.dart` continue to pass.
- **[Risk] Existing app startup tests check `Running on:` and `LIVE` text** → **Mitigation**: Keep `BrandyFly`, `LIVE`, and `Running on: $platformVersion` visible by default in `RecordingStatusOverlay` so `app_test.dart` and `platform_fallback_integration_test.dart` pass without modification.
