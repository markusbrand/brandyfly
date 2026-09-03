## ADDED Requirements

### Requirement: Fractional Grid Container System
The application SHALL render all flight screen layouts within a discrete fractional grid container that adapts to device orientation: an 8x8 grid in portrait mode and a 12x8 grid in landscape/tablet mode.

#### Scenario: Portrait layout grid instantiation
- **WHEN** the mobile application displays a flight screen in portrait orientation
- **THEN** the layout container SHALL divide the available canvas into an 8-column by 8-row fractional grid and position all placed widgets according to their fractional `(x, y, w, h)` coordinates.

#### Scenario: Landscape/tablet layout grid instantiation
- **WHEN** the application detects a landscape orientation or a tablet aspect ratio
- **THEN** the layout container SHALL divide the canvas into a 12-column by 8-row fractional grid and adjust widget horizontal positions and widths according to landscape layout rules.

### Requirement: Minimum Widget Cell Constraints and Clamping
Each widget type SHALL define immutable minimum cell width and height constraints. The layout engine MUST NOT permit any widget to be resized below its defined minimum dimensions or placed outside the grid bounds.

#### Scenario: Widget resize constraint enforcement
- **WHEN** a user resizes a Vario Bar widget below 1 column or 4 rows (or a Map widget below 4x4 cells)
- **THEN** the layout engine SHALL clamp the dimensions to the minimum allowed cell boundaries (Vario Bar min 1x4, Map min 4x4, Numeric min 2x1, Wind min 2x2, Sparkline min 4x2).

#### Scenario: Out-of-bounds positioning prevention
- **WHEN** a widget is dragged towards the outer perimeter of the screen
- **THEN** the layout engine SHALL constrain widget `x + w <= gridColumns` and `y + h <= gridRows` preventing viewport clipping.

### Requirement: Interactive Edit Mode Gestures
The flight screen SHALL provide an interactive edit mode activated by a long-press gesture on any widget or via the screen configuration action in the navigation drawer. In edit mode, widgets MUST support drag-to-move, corner-drag/pinch resizing, and swap handles.

#### Scenario: Long-press activation of edit mode
- **WHEN** the pilot performs a long-press (>= 500 ms) on any instrument widget during flight view
- **THEN** the application SHALL trigger haptic feedback, enter interactive layout edit mode, display bounding box outlines, and reveal resize and swap handles.

#### Scenario: Drag-to-move with live snapping
- **WHEN** the user drags a widget across the grid canvas in edit mode
- **THEN** the canvas SHALL display real-time grid snap target highlights and update the widget's fractional grid origin coordinates upon release.

#### Scenario: Widget swap gesture
- **WHEN** the user drags a widget's swap handle directly over another existing widget of matching or compatible dimensions
- **THEN** the canvas SHALL highlight both widgets and exchange their origin positions upon release.

### Requirement: Collision Detection and Snapping Feedback
The interactive canvas MUST detect overlapping collisions between widgets in real time and provide immediate visual indicators.

#### Scenario: Overlapping collision visual indicator
- **WHEN** a dragged or resized widget overlaps the cell space of an existing widget without swapping
- **THEN** the canvas SHALL highlight the colliding region with a semi-transparent red alert outline and prevent finalizing the placement until a collision-free or auto-pushed position is resolved.

### Requirement: Contract Schema for Profile Layouts
The repository SHALL define and enforce a strict JSON schema for flight screen profiles in `packages/contracts`, supporting serialization, deserialization, and schema validation.

#### Scenario: Profile schema contract validation
- **WHEN** a serialized layout JSON payload is validated against `packages/contracts` test fixtures
- **THEN** the validator SHALL confirm that all required fields (`schemaVersion`, `screens`, `widgets`, `gridDimensions`, `widgetStyles`) conform to the contract specification.

### Requirement: QR Code and Clipboard Export/Import
The application SHALL support exporting and importing complete screen layout profiles or individual screen designs via compressed QR code payloads and system clipboard JSON strings.

#### Scenario: Layout export via QR code
- **WHEN** a pilot selects "Share Layout via QR Code" for a profile
- **THEN** the app SHALL serialize and compress the layout configuration into a QR code display dialog suitable for scanning by another device camera.

#### Scenario: Layout import from clipboard or QR scan
- **WHEN** a pilot scans a valid layout QR code or pastes a valid layout JSON string from the clipboard
- **THEN** the application SHALL validate the payload against the contract schema, display a layout preview summary, and allow one-tap import into the pilot's saved screens.
