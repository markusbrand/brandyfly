## Context

See proposal.md for motivation. The current `layout_strategy_container.dart` (2,461 lines) concentrates grid layout, edit-mode UI, configuration dialogs, and widget rendering in a single file. The `AnimatedBuilder` wrapping `MaterialApp` in `main.dart` causes full-tree rebuilds on every `ScreenManagerService` notification. Several hot-path allocations in replay and synthetic telemetry degrade frame pacing during active flight.

## Goals / Non-Goals

**Goals:**
- Decompose the monolithic layout container into 4 focused modules
- Eliminate unnecessary widget tree rebuilds by scoping listeners
- Remove garbage-generating patterns from 10+ Hz telemetry hot paths
- Fix the simulation overlay blocking all touch events
- Add zero-dimension safety guards to all CustomPainters
- Ensure `const` constructors and `RepaintBoundary` on leaf widgets

**Non-Goals:**
- Storage migration from SharedPreferences to SQLite (separate change)
- PMTiles concurrency fix (separate change)
- Thermal map TextPainter caching (valuable but invasive; deferred to dedicated thermal-map optimization change)
- Changing the `Map<String, dynamic>` telemetry pipeline to `TelemetrySnapshot` throughout (scoped to replay service only in this change)

## Decisions

### Decision 1: File decomposition strategy for layout_strategy_container.dart

Extract into 4 files:
1. `layout_strategy_container.dart` — Retains `LayoutStrategyContainer` (grid computation, strategy dispatch, `_renderWidgetContent`). ~400 lines.
2. `widget_edit_frame.dart` — `WidgetEditFrame` (drag/resize gesture handling, edit-mode chrome). ~350 lines.
3. `widget_config_dialog.dart` — `showWidgetConfigDialog()` top-level function (the ~900-line `StatefulBuilder` dialog). ~900 lines.
4. `widget_inspector_panel.dart` — `WidgetInspectorPanel` (bottom inspector with nudge/resize/layer controls). ~200 lines.

**Rationale**: These four units have distinct responsibilities and no circular dependencies. The layout container creates edit frames; edit frames call the config dialog; the inspector panel calls screen manager methods. This aligns with the recommended Flutter architecture skill's separation of UI components by feature.

**Alternative considered**: Keeping edit frame and inspector in one file. Rejected because the inspector panel is also invoked from the layout container's bottom overlay, making it a shared component.

### Decision 2: Move AnimatedBuilder below MaterialApp

Current:
```dart
AnimatedBuilder(
  animation: _screenManager,
  builder: (_, __) => MaterialApp(...)
)
```

Changed to:
```dart
MaterialApp(
  home: AnimatedBuilder(
    animation: _screenManager,
    builder: (_, __) => <page selection logic>
  )
)
```

**Rationale**: `MaterialApp` constructs theme, navigator, and localizations. Rebuilding it on every screen toggle is wasteful. Moving the listener to `home:` scopes rebuilds to the page content only.

**Alternative considered**: Using `ValueListenableBuilder` for individual properties. Rejected because `ScreenManagerService` already extends `ChangeNotifier` and the granularity of a single `AnimatedBuilder` at the page level is sufficient.

### Decision 3: Fix simulation overlay hit-testing

Current: `Positioned.fill(child: _SimulationControlOverlay(...))` makes the overlay consume the entire screen's touch area.

Changed to: Remove `Positioned.fill` and use the existing `Positioned(left:, top:, right:)` pattern that the overlay already computes internally, combined with `IgnorePointer` or `HitTestBehavior.translucent` on the outer Stack layer so that only the visible card area captures touches.

**Rationale**: The overlay already calculates its own position via `_overlayPosition` and renders a constrained card. The `Positioned.fill` wrapper is the only thing causing the full-screen hit-test interception.

### Decision 4: Incremental track list caching in FlightReplayService

Replace:
```dart
final track = _flight?.points.take(_currentIndex + 1).map(...).toList();
```

With a cached `_trackCache` list that appends one `LatLng` per `advance()` call and resets on `loadFlight()` or `seekTo()`.

**Rationale**: For a 2-hour flight (~7,200 points), the current pattern allocates 7,200 LatLng objects + a new list on every tick. Incremental append is O(1) per tick.

### Decision 5: Mathematical rounding in SyntheticTelemetrySource

Replace:
```dart
altitude: double.parse(_altitude.toStringAsFixed(1)),
```

With:
```dart
altitude: (_altitude * 10).roundToDouble() / 10.0,
```

**Rationale**: Eliminates 12 string allocations per tick at 10 Hz (120 string allocs/sec → 0). No functional difference in output precision.

### Decision 6: Zero-dimension guard pattern

All `CustomPainter.paint()` methods that iterate using canvas dimensions SHALL begin with:
```dart
if (size.width <= 0 || size.height <= 0) return;
```

**Rationale**: Prevents the identified infinite loop in `AltitudeSparklineChart` where `size.width / 5 == 0` causes an infinite `for` loop.

## Risks / Trade-offs

- **[Risk] File decomposition may break existing tests** → Mitigation: All existing widget tests reference `LayoutStrategyContainer` by import; the public API surface (`LayoutStrategyContainer` class and constructor) remains unchanged. Internal classes become public in their new files.
- **[Risk] Moving AnimatedBuilder below MaterialApp changes theme rebuild scope** → Mitigation: Theme is static (`ThemeData` from `ColorScheme.fromSeed`); no dynamic theme changes exist in the app.
- **[Risk] Incremental track caching in replay may diverge from source-of-truth on seek** → Mitigation: `seekTo()` and `loadFlight()` both reset the cache by re-slicing up to the target index.
- **[Risk] Edit frame and inspector extraction may affect key-based widget identity** → Mitigation: All existing `Key` values are preserved in the extracted widgets; only the file location changes.

## Migration Plan

1. All changes are internal refactoring with no user-facing API, database, or protocol changes.
2. No deployment migration required.
3. Rollback: Revert the Git commit.
