## MODIFIED Requirements

### Requirement: Screen-Level Layout Strategy and Management
Each flight screen SHALL encapsulate its own layout strategy, unique screen identifier, display title, auto-switching trigger rules, and ordered collection of placed widgets. The system SHALL preserve the active screen identifier and widget selection state when modifying or deleting inactive screens, only transitioning the active screen when the currently active screen is explicitly deleted. Automatic switching SHALL follow the thermal assistant flight mode and climb rate, and SHALL be evaluated continuously so that a switch suppressed by the rate limit, manual override, or edit mode is applied as soon as the suppression ends and its condition still holds.

#### Scenario: Screen-specific layout strategy rendering
- **WHEN** a flight screen is configured with a specific layout strategy (e.g. Freeform HUD, Snap-to-Grid, or Sidebar Dashboard)
- **THEN** the application SHALL render that screen using its defined strategy without affecting the layout strategy of other screens

#### Scenario: Auto-switching screen trigger execution
- **WHEN** the thermal assistant flight mode is circling, the average climb rate is above 0 m/s, telemetry is not stale, and a screen is configured with the thermal circling trigger
- **THEN** the application SHALL automatically switch the active view to the first screen (in screen order) configured with the thermal circling trigger
- **AND** SHALL remember the screen that was active before the switch

#### Scenario: Circling in sink does not switch
- **WHEN** the thermal assistant flight mode is circling but the average climb rate is 0 m/s or below
- **THEN** the application SHALL NOT switch to the thermal circling screen
- **AND** SHALL switch once the average climb rate rises above 0 m/s while the pilot is still circling

#### Scenario: Auto-switching back on straight glide
- **WHEN** the thermaling screen is shown due to an automatic switch and the pilot has flown straight (heading within ±15°) for at least 10 s
- **THEN** the application SHALL switch to the first screen configured with the glide-straight trigger if one exists
- **AND** otherwise SHALL return to the screen that was active before the automatic switch
- **AND** SHALL perform this switch no later than 12 s after straight flight began, unless suppressed by edit mode or manual override

#### Scenario: Renewed circling cancels the pending return
- **WHEN** the flight mode returns to circling before 10 s of straight flight have elapsed
- **THEN** the application SHALL remain on the thermaling screen

#### Scenario: Short search turn returns to the normal screen
- **WHEN** an automatic switch to the thermaling screen occurred and the pilot flies straight again so that the return condition is met less than 10 s after that switch
- **THEN** the application SHALL return to the previous screen as soon as 10 s have passed since the automatic switch

#### Scenario: Manual override suppresses auto-switching
- **WHEN** the pilot manually selects a different screen
- **THEN** the application SHALL NOT perform automatic screen switches for the next 60 s
- **AND** SHALL NOT automatically return to a previously remembered screen

#### Scenario: Auto-switching rate limit and edit mode
- **WHEN** an automatic switch condition arises less than 10 s after the previous automatic switch, or while layout edit mode is active
- **THEN** the application SHALL NOT switch the active screen at that moment
- **AND** SHALL apply the switch once the suppression ends if the condition still holds

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
