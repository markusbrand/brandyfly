# Tasks

## 1. Shared Draggable Overlay Container & Simulation Overlay Refactor

- [x] 1.1 Create `DraggableOverlayContainer` in `apps/mobile/lib/ui/core/widgets/draggable_overlay_container.dart` supporting 2D pan-to-move repositioning, `MediaQuery` safe-area and viewport boundary clamping, dynamic size re-clamping on expand/collapse or viewport resize, and touch passthrough outside card bounds, and verify with unit/widget tests in `apps/mobile/test/ui/core/draggable_overlay_container_test.dart`.
- [x] 1.2 Refactor `_SimulationControlOverlay` in `apps/mobile/lib/main.dart` to use `DraggableOverlayContainer` while preserving `Key('simulation_overlay_card')`, `Key('btn_minimize_mock_session')`, `Key('btn_expand_mock_session')`, and all simulation controls, and verify `flutter test test/app_test.dart` passes.

## 2. Moveable Live Recording Status Overlay & Manual Recording Controls

- [x] 2.1 Add `startManualRecording()` and `stopManualRecording()` methods to `FlightTrackingService` in `apps/mobile/lib/services/flight_tracking_service.dart` so pilots can manually start recording from `GroundPreflight` (prepending buffered points) and manually finalize recording from `Flying`, and verify with unit tests in `apps/mobile/test/flight_tracking_service_test.dart`.
- [x] 2.2 Implement `RecordingStatusOverlay` in `apps/mobile/lib/widgets/flight/recording_status_overlay.dart` wrapped in `DraggableOverlayContainer` displaying `BrandyFly`, `LIVE`/`REPLAY` mode badge, live recording state (`STANDBY`, `REC <duration>`, `LANDED`), manual start/stop button (`Key('btn_manual_record_toggle')`), and collapsible `Running on: <platform>` status (`Key('btn_recording_overlay_collapse')` / `Key('btn_recording_overlay_expand')`).
- [x] 2.3 Wire `RecordingStatusOverlay` into `_LiveFlightView` in `apps/mobile/lib/main.dart` and verify with widget tests covering drag repositioning, safe-area clamping, manual start/stop recording, and existing startup/fallback tests (`flutter test test/app_test.dart test/platform_fallback_integration_test.dart`).

## 3. Moveable Replay Control Overlay

- [x] 3.1 Update `ReplayControlOverlay` in `apps/mobile/lib/widgets/flight/replay_control_overlay.dart` and its placement in `apps/mobile/lib/main.dart` to use `DraggableOverlayContainer` for 2D free-dragging across the viewport in both expanded and minimized states, while preserving tap-to-collapse/expand on `Key('replay_bottom_grab_handle')` and `Key('btn_replay_collapse')` / `Key('btn_replay_expand')`, timeline slider scrubbing, and speed multiplier cycling.
- [x] 3.2 Add and update widget tests in `apps/mobile/test/widgets_test.dart` and `apps/mobile/test/instrument_widgets_test.dart` to verify `ReplayControlOverlay` 2D drag repositioning, boundary clamping on expand/collapse, slider scrubbing, and speed cycling (`flutter test test/widgets_test.dart test/instrument_widgets_test.dart test/flights_screen_widget_test.dart`).

## 4. Unified Moveable & Collapsible Edit Mode Dock

- [x] 4.1 Update `_buildEditDock` in `apps/mobile/lib/ui/features/flight_canvas/views/layout_canvas.dart` into a unified Edit Mode Dock (`_EditDockOverlay`) combining `WidgetInspectorPanel` and `EditToolbar` with:
  - Smart auto-dodge default positioning (flipping the entire unified dock to the top when a lower-half widget is selected on tall canvases, or left/right on wide canvases).
  - Free 2D drag repositioning (`Key('edit_dock_drag_handle')`) clamped within the viewport safe area that overrides auto-dodge until reset (`Key('btn_edit_dock_auto_dodge')`) or Edit Mode exit.
  - One-tap minimize/expand (`Key('btn_edit_dock_minimize')` / `Key('btn_edit_dock_expand')`) that collapses the dock into a compact floating pill (`Add Widget`, `Expand`, `Done`) for unobstructed 16x32 grid inspection.
- [x] 4.2 Add widget tests in `apps/mobile/test/ui/flight_canvas_test.dart` verifying unified dock auto-dodge (both inspector and toolbar move away from lower-half selections), manual 2D dragging and clamping, reset to auto-dodge, and minimize/expand pill behavior (`flutter test test/ui/flight_canvas_test.dart`).

## 5. Full Suite Validation

- [x] 5.1 Run `flutter analyze` and the full mobile test suite (`flutter test`) in `apps/mobile`, plus `npx openspec validate --all --strict`, and verify zero warnings or test failures.

## Workflow follow-up

- Verify implementation with `openspec-verify-change` and `npx openspec validate --all --strict`.
- Archive the change with `npx openspec archive moveable-cockpit-overlays --yes`, update promoted spec descriptions if needed, commit, push `feature/moveable-cockpit-overlays`, and open a Pull Request targeting `main`.
