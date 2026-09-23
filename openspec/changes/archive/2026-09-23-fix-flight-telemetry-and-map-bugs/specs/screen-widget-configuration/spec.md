## MODIFIED Requirements

### Requirement: Screen-Level Layout Strategy and Management
Each flight screen SHALL encapsulate its own layout strategy, unique screen identifier, display title, auto-switching trigger rules, and ordered collection of placed widgets. The system SHALL preserve the active screen identifier and widget selection state when modifying or deleting inactive screens, only transitioning the active screen when the currently active screen is explicitly deleted.

#### Scenario: Screen-specific layout strategy rendering
- **WHEN** a flight screen is configured with a specific layout strategy (e.g. Freeform HUD, Snap-to-Grid, or Sidebar Dashboard)
- **THEN** the application SHALL render that screen using its defined strategy without affecting the layout strategy of other screens

#### Scenario: Auto-switching screen trigger execution
- **WHEN** flight telemetry indicates sustained circling lift and a screen is configured with the thermal circling trigger
- **THEN** the application SHALL automatically switch the active view to that thermaling screen

#### Scenario: Removing an inactive screen maintains active screen and widget selection
- **WHEN** the user or system removes a screen whose ID is not the active screen ID
- **THEN** the application SHALL remove the target screen from the configuration
- **AND** the active screen ID and selected widget ID SHALL remain unchanged

#### Scenario: Removing non-existent screen ID is a safe no-op
- **WHEN** a screen removal request is received for an ID that does not exist in the screen configuration
- **THEN** the application SHALL retain the existing screen configuration, active screen ID, and widget selection without broadcasting spurious change notifications

#### Scenario: Removing active screen transitions to next available screen
- **WHEN** the user removes the screen that is currently active and other screens remain
- **THEN** the application SHALL remove the screen, clear widget selection, and set the active screen ID to the first available remaining screen
