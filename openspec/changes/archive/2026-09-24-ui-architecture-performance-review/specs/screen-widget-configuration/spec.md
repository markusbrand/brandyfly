## ADDED Requirements

### Requirement: Simulation overlay touch passthrough
The simulation control overlay SHALL NOT intercept touch events on the flight instrument widgets beneath it. The overlay SHALL only capture gestures within its own visible card bounds, allowing pilots to interact with map widgets, instrument panels, and other flight controls while the simulation overlay is visible.

#### Scenario: Tapping a map widget beneath the simulation overlay
- **WHEN** the simulation control overlay is visible and the pilot taps on a visible area of a map widget that is not obscured by the overlay card
- **THEN** the tap SHALL be received by the map widget and the simulation overlay SHALL NOT consume the gesture event

#### Scenario: Dragging the simulation overlay card
- **WHEN** the pilot drags within the visible bounds of the simulation overlay card
- **THEN** the overlay card SHALL reposition according to the drag gesture and the underlying flight instruments SHALL NOT receive the drag event

### Requirement: Modular layout container architecture
The layout strategy container implementation SHALL be decomposed into focused architectural units: a layout engine responsible for grid computation and strategy selection, an edit-mode inspector panel, a widget configuration dialog, and a widget content renderer. Each unit SHALL be maintainable and testable independently.

#### Scenario: Layout engine computes grid without UI concerns
- **WHEN** the layout container renders a flight screen with any layout strategy
- **THEN** the grid cell dimensions, content height, and widget positioning SHALL be computed by a dedicated layout engine that does not contain edit-mode inspector UI, configuration dialog code, or widget content rendering logic

#### Scenario: Widget configuration dialog is independently importable
- **WHEN** a developer needs to modify the widget configuration dialog
- **THEN** the dialog SHALL reside in its own Dart file and SHALL be importable and testable without importing the entire layout container

### Requirement: Safe unbounded constraint handling in layout container
The layout container SHALL handle unbounded vertical constraints (e.g., when embedded inside a scrollable parent) by falling back to a reasonable default cell height rather than computing `infinity / N` which causes a fatal layout crash.

#### Scenario: Layout container inside unbounded vertical parent
- **WHEN** the `LayoutStrategyContainer` receives `constraints.maxHeight == double.infinity`
- **THEN** the container SHALL use a fallback cell height value and SHALL NOT crash or produce infinite layout dimensions
