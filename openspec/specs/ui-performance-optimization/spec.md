# ui-performance-optimization Specification

## Purpose
Establishes performance guardrails for the BrandyFly flight cockpit UI, ensuring scoped widget rebuilds, RepaintBoundary isolation, const constructor enforcement, and garbage-free hot-path contracts to maintain smooth frame rates during active flight telemetry rendering.

## Requirements

### Requirement: Scoped widget rebuilds
The flight cockpit UI SHALL scope `ListenableBuilder` and `AnimatedBuilder` listeners to the narrowest possible subtree so that telemetry updates, edit-mode state changes, and overlay toggles do not trigger full-screen rebuilds of unrelated widget branches.

#### Scenario: Telemetry update does not rebuild MaterialApp
- **WHEN** the telemetry source emits a new data snapshot at 10 Hz
- **THEN** only the individual instrument widgets (altitude, speed, vario bar, etc.) SHALL rebuild; the MaterialApp, theme configuration, and route scaffold SHALL NOT rebuild

#### Scenario: Edit-mode toggle does not rebuild instrument content
- **WHEN** the user enters or exits layout edit mode
- **THEN** only the edit-mode overlay controls SHALL rebuild; the underlying instrument widget content SHALL NOT be destroyed and recreated

### Requirement: RepaintBoundary isolation on custom painters
Every `CustomPaint` widget rendering flight telemetry (sparkline charts, vario bars, thermal maps, flight track overlays) SHALL be wrapped in a `RepaintBoundary` so that paint invalidation does not propagate beyond the boundary to parent or sibling widgets.

#### Scenario: Vario bar repaint does not cascade
- **WHEN** the vario climb rate value changes at 20 Hz
- **THEN** only the `VarioLiftSinkBar` subtree SHALL repaint; adjacent altitude and speed widgets SHALL NOT repaint

#### Scenario: Thermal map pulse animation is isolated
- **WHEN** the thermal map pulse animation controller fires at 60 FPS
- **THEN** the repaint SHALL be contained within the thermal map widget boundary and SHALL NOT cause the parent layout container to repaint

### Requirement: Garbage-free telemetry hot paths
Telemetry processing code executing at 10 Hz or faster SHALL NOT allocate temporary `String` objects for numeric rounding, SHALL NOT create new `List` instances from existing data on every tick, and SHALL NOT instantiate `Paint`, `Path`, or `TextPainter` objects inside `paint()` methods on every frame.

#### Scenario: Synthetic telemetry rounding uses math operations
- **WHEN** the `SyntheticTelemetrySource` generates a telemetry snapshot at 10 Hz
- **THEN** numeric values SHALL be rounded using mathematical operations (e.g., `(val * 10).round() / 10.0`) instead of `double.parse(toStringAsFixed())`

#### Scenario: Replay track list is cached incrementally
- **WHEN** the `FlightReplayService` advances by one point during playback
- **THEN** the track list SHALL be extended incrementally rather than re-slicing the full point array

#### Scenario: CustomPainter reuses allocated objects
- **WHEN** a `CustomPainter.paint()` method executes for any flight instrument widget
- **THEN** `Paint`, `Path`, and `TextPainter` instances SHALL be cached as class fields and reused across frames

### Requirement: Zero-dimension paint safety guard
All `CustomPainter` implementations SHALL guard against zero or negative canvas dimensions before executing drawing loops, preventing infinite loops that freeze the UI thread.

#### Scenario: Sparkline chart with zero-size canvas
- **WHEN** `AltitudeSparklineChart` receives layout constraints with `width == 0` or `height == 0`
- **THEN** the painter SHALL return immediately without executing grid drawing loops and SHALL NOT enter an infinite iteration

### Requirement: Const constructor enforcement on leaf widgets
Stateless leaf widgets that accept only primitive or enum parameters SHALL use `const` constructors, and static decoration objects, text styles, and edge insets SHALL be declared as `const` where the values are compile-time constants.

#### Scenario: ModeChip uses const constructor
- **WHEN** the `_ModeChip` widget is instantiated with a label string and color
- **THEN** the widget SHALL be eligible for const construction and Flutter's widget identity optimization
