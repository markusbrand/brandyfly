## MODIFIED Requirements

### Requirement: Screen-Level Layout Strategy and Management
Each flight screen SHALL encapsulate its own layout strategy, unique screen identifier, display title, auto-switching trigger rules, and ordered collection of placed widgets. The system SHALL preserve the active screen identifier and widget selection state when modifying or deleting inactive screens, only transitioning the active screen when the currently active screen is explicitly deleted. Auto-switching SHALL be driven by the on-device thermal assistant flight mode, SHALL be suppressed while layout edit mode is active, and SHALL NOT switch screens more than once within 10 s.

#### Scenario: Screen-specific layout strategy rendering
- **WHEN** a flight screen is configured with a specific layout strategy (e.g. Freeform HUD, Snap-to-Grid, or Sidebar Dashboard)
- **THEN** the application SHALL render that screen using its defined strategy without affecting the layout strategy of other screens

#### Scenario: Auto-switching screen trigger execution
- **WHEN** the thermal assistant flight mode changes from gliding to circling and a screen is configured with the thermal circling trigger
- **THEN** the application SHALL automatically switch the active view to the first screen (in screen order) configured with the thermal circling trigger
- **AND** SHALL remember the screen that was active before the switch

#### Scenario: Auto-switching back on straight glide
- **WHEN** the thermal assistant flight mode changes from circling to gliding after an automatic switch to a thermal circling screen
- **THEN** the application SHALL switch to the first screen configured with the glide-straight trigger if one exists
- **AND** otherwise SHALL return to the screen that was active before the automatic switch

#### Scenario: Manual override suppresses auto-switching
- **WHEN** the pilot manually selects a different screen
- **THEN** the application SHALL NOT perform automatic screen switches for the next 60 s

#### Scenario: Auto-switching rate limit and edit mode
- **WHEN** a flight-mode transition occurs less than 10 s after the previous automatic switch, or while layout edit mode is active
- **THEN** the application SHALL NOT switch the active screen

#### Scenario: No configured trigger
- **WHEN** no screen is configured with a matching trigger
- **THEN** the active screen SHALL remain unchanged on flight-mode transitions

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
