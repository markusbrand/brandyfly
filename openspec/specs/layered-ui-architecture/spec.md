# layered-ui-architecture Specification

## Purpose
Keeps flight canvas, layout editing and map control code maintainable and testable by separating presentation, state, layout rules and persistence into independently testable layers with injected dependencies.

## Requirements

### Requirement: Layout Rules Independent of the Widget Tree
Layout editing rules (bounds clamping, catalog minimums, presets, nudging, resizing, overlap detection, alignment detection, variant copy, legacy migration) SHALL be implemented in a domain layer that has no dependency on Flutter widgets, rendering or persistence, and SHALL be exercisable by plain unit tests.

#### Scenario: Rule unit tests run without widgets
- **WHEN** the layout rule test suite runs
- **THEN** it SHALL execute without pumping a widget tree or initializing platform plugins.

#### Scenario: Single source of rules
- **WHEN** a widget is resized through corner drag, steppers, inspector, configuration sheet or presets
- **THEN** all paths SHALL delegate to the same layout rule implementation and produce identical results for identical inputs.

### Requirement: Persistence Isolated Behind a Repository
Loading, saving, schema versioning, migration and backup of the UI configuration SHALL be owned by a layout repository that is the single source of truth for layouts. View models SHALL NOT access storage directly.

#### Scenario: Repository with in-memory storage
- **WHEN** the layout repository is constructed with an in-memory storage service in tests
- **THEN** load, save, migration and backup behavior SHALL be verifiable without device storage.

#### Scenario: Storage write failure
- **WHEN** persisting a layout change fails
- **THEN** the in-memory layout SHALL keep the change for the session and the failure SHALL be reported without crashing the flight view.

### Requirement: View Models Expose Immutable State
Flight canvas, edit mode and map camera view models SHALL expose immutable state snapshots and command methods; views SHALL be lean widgets that render state and forward user interactions to commands.

#### Scenario: View model unit test
- **WHEN** an edit mode view model receives select, nudge, resize, preset, reorder and delete commands in a unit test
- **THEN** its published state SHALL reflect each command and notify listeners exactly once per effective change, and not at all for no-op commands.

### Requirement: Injected Dependencies
Services, repositories and view models SHALL be provided through constructor injection and a dependency injection scope at the application root, so that tests can substitute fakes for map, storage and telemetry services without modifying production code.

#### Scenario: App test with fakes
- **WHEN** the application is pumped in a test with fake map, storage and telemetry services
- **THEN** the flight canvas, edit mode and map controls SHALL operate using those fakes.
