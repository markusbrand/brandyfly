# Proposal: UI Performance, Accessibility Hardening, Architecture Refactoring, and Dense Unit Testing

## Why

In safety-critical paragliding scenarios, pilots need immediate, latency-free feedback from flight instrumentation, smooth vector/raster map rendering without skipped frames or main-thread stalls, and clear, highly accessible UI elements that can be operated reliably in flight gloves and direct sunlight. Recent testing revealed layout overflows in compact edit mode widgets, status bar overlap with navigation handles, low contrast telemetry elements, and opportunities to streamline the telemetry pipeline and eliminate redundant UI rebuilds while providing an exhaustive unit and widget test suite for regression-free test-driven development.

## What Changes

- **UI Accessibility & Ergonomics Hardening**:
  - Resolve `RenderFlex` overflows in `LayoutStrategyContainer` widget headers and toolbars for compact (1x1, 2x1, 2x2) dimensions.
  - Fix status bar clipping and safe area positioning for `TopNavBarOverlay` grab handle and badges to ensure reliable touch targets (>= 48x48dp) and prevent collision with system status bar.
  - Improve high-contrast readability, semantic accessibility labels (`Semantics`), and touch boundaries across all instrument widgets, settings panels, and flight logbook sheets.
  - Clean up simulation control overlay layout, ensuring collapsed mode hides overflowing text and defaults to non-obstructive placement without covering primary flight data.

- **Maximum Performance & Latency Optimization**:
  - Eliminate main-thread stalls and frame skipping during map rendering and telemetry updates.
  - Optimize `MapWidget` and `ThermalMapWidget` polyline and marker update paths to avoid re-allocating point arrays and rebuilding expensive widget subtrees on every tick.
  - Optimize `FlightTrackingService` and `SyntheticTelemetrySource` event dispatching, ensuring micro-benchmarked minimal latency between sensor ingestion and widget display.
  - Add `const` constructors, `RepaintBoundary` wrappers, and cached path/paint objects in custom painters (`MiniTrackPainter`, `AltitudeSparklineChart`, `VarioLiftSinkBar`).

- **Architecture Refactoring & Dead Code Elimination**:
  - Audit all mobile app modules (`models`, `services`, `widgets`), pruning obsolete helpers, unused imports, duplicate math calculations, and stale placeholders.
  - Clean up and decouple state interactions between `ScreenManagerService`, `FlightTrackingService`, and `MapLibreMapService`.

- **Dense Unit & Widget Test Suite**:
  - Expand test coverage across flight models, tracking services, replay systems, telemetry providers, UI persistence, and widget rendering.
  - Create dense, exhaustive test cases verifying zero-overflow constraints, boundary clamping, safe area adaptations, low-latency telemetry updates, and error handling for resilient test-driven development.

## Capabilities

### Modified Capabilities
- `screen-widget-configuration`: Refine requirements to mandate zero-overflow layout resilience for compact widget dimensions (1x1 to 8x16), safe-area compliant navigation grab handles with accessible tap targets (>= 48x48dp), and high-contrast styling.
- `simulation-overlay-control`: Mandate clean collapsed layout without content clipping, non-obstructive positioning relative to primary flight instruments, and isolated touch event propagation.
- `offline-vector-map-rendering`: Mandate sub-millisecond telemetry synchronization and low-overhead polyline batching without frame drops or main-thread stalls.

## Non-Goals
- Changing external cloud backend services or modifying backend Go server API contracts.
- Adding new hardware BLE vario drivers (e.g. physical BlueFly or XC Tracer) in this change; focus is on UI/client core architecture, performance, accessibility, and local mock testing.

## Impact & Governance
- **Privacy & Safety**: Telemetry coordinates and flight logs remain local-first on device. All flight-critical instrumentation functions strictly offline.
- **Offline Reliability**: All map rendering, vario calculations, and UI layouts operate deterministically offline without network calls.
- **Licensing**: Fully MIT-compliant, utilizing established dependencies without adding restrictive proprietary packages.
