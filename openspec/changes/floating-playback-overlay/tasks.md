## 1. Replay Overlay Floating Drag & Layout Integration

- [x] 1.1 Refactor `ReplayControlOverlay` in `apps/mobile/lib/widgets/flight/replay_control_overlay.dart` to support free-floating drag repositioning using `LayoutBuilder`, `GestureDetector`, and dynamic boundary clamping against viewport size and safe area padding. Verify with `flutter analyze lib/widgets/flight/replay_control_overlay.dart`.
- [x] 1.2 Update `apps/mobile/lib/main.dart` to mount `ReplayControlOverlay` with `Positioned.fill` within the root flight screen stack, ensuring session-only position lifetime resets upon replay exit. Verify with `flutter analyze lib/main.dart`.

## 2. Interaction Precedence & Boundary Clamping

- [x] 2.1 Refine gesture arbitration and layout constraints so scrubber slider, playback control buttons, speed multiplier, close button, and expand/collapse toggle maintain discrete touch handling without triggering drags. Verify by testing tap and drag interactions in widget tests.
- [x] 2.2 Implement first-pan position calibration so dragging initiates smoothly from the default bottom position without visual jumping, and re-clamps dynamically when expanding/collapsing near screen edges. Verify boundary clamping calculations with automated unit/widget tests.

## 3. Automated Testing & Spec Verification

- [x] 3.1 Create dedicated widget test suite `apps/mobile/test/replay_control_overlay_test.dart` validating default positioning, drag panning, edge clamping, child control touch precedence, and session reset behavior. Verify by running `flutter test test/replay_control_overlay_test.dart`.
- [x] 3.2 Run complete Flutter test suite and OpenSpec strict validation across the workspace. Verify with `flutter test` in `apps/mobile` and `npx openspec validate --all --strict`.
