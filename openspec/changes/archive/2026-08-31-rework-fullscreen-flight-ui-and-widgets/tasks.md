## 1. Zero-Dead-Space Instrument Widgets Overhaul

- [x] 1.1 Rework `NumericTextWidget` styles (Minimalist, High Contrast, Circular Gauge, Retro Digital) to minimize padding and maximize digit typography size.
- [x] 1.2 Rework `VarioLiftSinkBar` styles (Vertical Edge Bar, Analog Dial, Screen Edge Glow) to dynamically fill and scale within its container without fixed-width empty spaces.
- [x] 1.3 Rework `WindDirectionWidget` and `AltitudeSparklineChart` to maximize graphic indicator and chart canvas density.
- [x] 1.4 Update widget unit tests in `apps/mobile/test/widgets_test.dart` to verify new high-density rendering across all styles.

## 2. Dynamic Fullscreen Layout Strategy Container

- [x] 2.1 Refactor `LayoutStrategyContainer` to eliminate artificial inner padding and dynamically scale grid cells to fill 100% of the display viewport.
- [x] 2.2 Ensure Map and Thermal Map widgets at full bounds span edge-to-edge seamlessly without borders or wasted margins.
- [x] 2.3 Verify Edit Mode resizing, drag-and-drop, and in-place configuration sheets operate smoothly on the edge-to-edge canvas.

## 3. On-Demand Gesture Overlays (Top Nav & Replay HUD)

- [x] 3.1 Enhance `TopNavBarOverlay` with smooth edge swipe-down detection, subtle grab indicator handle, and gesture dismissal.
- [x] 3.2 Refactor `ReplayControlOverlay` into a collapsible bottom overlay supporting swipe-up expansion and swipe-down minimization to a discreet pill/handle.
- [x] 3.3 Add widget tests in `apps/mobile/test/widgets_test.dart` validating pull-down navigation and collapsible replay overlay gestures.

## 4. Fullscreen Main Application Shell Integration

- [x] 4.1 Refactor `_LiveFlightView` and `_MockFlightView` in `apps/mobile/lib/main.dart` to eliminate static `AppBar` and `_SectionCard` list wrappers, rendering `LayoutStrategyContainer` full-screen.
- [x] 4.2 Streamline mock flight controls and live status into a discreet floating overlay pill/chip.
- [x] 4.3 Update `app_test.dart` and integration tests to validate the new fullscreen shell layout and on-demand overlay interactions.
- [x] 4.4 Run full test suite (`flutter test`) and static analysis (`dart analyze`) to confirm 100% pass and zero regressions.
