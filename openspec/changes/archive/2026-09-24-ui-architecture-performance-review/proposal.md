## Why

The BrandyFly mobile app has grown into a feature-rich paragliding vario, but the current architecture carries several performance bottlenecks, UI glitches, and code-quality issues that degrade flight-time reliability and developer maintainability. Key problems include:

- **Monolithic 2,461-line layout file** (`layout_strategy_container.dart`) that mixes widget rendering, edit-mode inspector panels, configuration dialogs, and grid layout math in a single file — violating separation of concerns and hindering testability.
- **Performance-critical hot paths allocating excessive garbage** — the `FlightReplayService.currentTelemetry` getter re-creates sublists of thousands of `LatLng`/`FlightPoint` objects on every tick; `SyntheticTelemetrySource` uses `double.parse(toStringAsFixed())` at 10 Hz (120 string allocs/sec) instead of mathematical rounding.
- **`MaterialApp` rebuilt on every `ScreenManagerService` state change** because the `AnimatedBuilder` wrapping it sits too high in the tree and doesn't scope rebuilds.
- **Missing `RepaintBoundary`** isolation on several custom painters and map widgets that cause full-screen repaints.
- **Untyped `Map<String, dynamic>` telemetry pipeline** flowing through the entire UI instead of the already-existing `TelemetrySnapshot` model.

Addressing these now prevents latency regressions as additional flight instruments, airspace overlays, and the Rust FFI core are integrated.

## What Changes

- **Decompose `layout_strategy_container.dart`** into focused files: grid layout engine, edit-mode inspector panel, widget configuration dialog, and widget content renderer.
- **Eliminate garbage-generating hot paths**: cache replay track lists incrementally; replace string-based rounding with math rounding in synthetic telemetry.
- **Scope `MaterialApp` rebuilds**: move `AnimatedBuilder` below `MaterialApp` so theme/route infrastructure isn't reconstructed on screen-manager state changes.
- **Add `const` constructors and `RepaintBoundary`** to leaf widgets (`_ModeChip`, `_LoadingView`, status overlays) where missing.
- **Remove duplicate `setState` rebuild triggers** in `_BrandyFlyAppState` where `_mockReplay.advance()` is called both by the periodic timer and by the simulation overlay buttons.
- **Fix `_SimulationControlOverlay` hit-testing**: the `Positioned.fill` wrapper intercepts all touches across the entire screen when the overlay is visible, blocking interaction with underlying flight instruments.
- **Standardize telemetry flow**: migrate UI widgets to consume `TelemetrySnapshot` directly instead of `Map<String, dynamic>`.

## Capabilities

### New Capabilities
- `ui-performance-optimization`: Establishes performance guardrails — scoped rebuilds, RepaintBoundary usage, const widget enforcement, and garbage-free hot-path contracts for the flight cockpit UI.

### Modified Capabilities
- `screen-widget-configuration`: Decomposition of the monolithic layout container into focused architectural units; fixes hit-test passthrough bug on simulation overlay.

## Impact

- **Code**: All files under `apps/mobile/lib/widgets/layout/`, `apps/mobile/lib/main.dart`, `apps/mobile/lib/services/flight_replay_service.dart`, `apps/mobile/lib/services/telemetry/synthetic_telemetry_source.dart`.
- **APIs**: Internal only — no public API changes. Widget constructor signatures may add `const` or receive `TelemetrySnapshot` instead of `Map<String, dynamic>`.
- **Dependencies**: No new dependencies added.
- **Safety**: All changes preserve offline-first operation and do not modify flight-critical telemetry processing logic. Sensor/audio loops remain independent of the Flutter UI thread.

## Non-Goals

- **Storage migration** from `SharedPreferences` to SQLite/Isar (separate change).
- **PMTiles race condition fix** (concurrency-specific change).
- **XContest API real implementation** (separate integration work).
- **Password security** migration to `FlutterSecureStorage` (security-focused change).
- **Rust FFI bridge** integration (pending `crates/` work).
