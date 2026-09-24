## MODIFIED Requirements

### Requirement: On-Demand Gesture-Driven Top Navigation Overlay
The main navigation drawer and application controls SHALL remain hidden during flight and SHALL slide down on demand as a temporary overlay when triggered by a swipe-down gesture or top edge grab handle. All buttons, screen selector chips, and dialog triggers within the navigation drawer SHALL reliably register discrete click/tap events without interference or cancellation from enclosing scroll containers or underlying map view gesture recognizers.

#### Scenario: Swipe down from top screen edge reveals navigation overlay
- **WHEN** the pilot swipes down from the top edge of the screen (or taps the top grab handle)
- **THEN** the top navigation overlay SHALL slide smoothly into view over the flight canvas
- **AND** provide access to screen switching, edit mode, flights logbook, and settings.

#### Scenario: Dismissing top navigation overlay
- **WHEN** the pilot swipes up on the open navigation overlay or taps the backdrop area outside the drawer
- **THEN** the navigation overlay SHALL slide back up and hide, returning 100% of the screen to the flight instruments.

#### Scenario: Clicking screen selector chips in navigation drawer
- **WHEN** the pilot clicks any screen selector chip (whether switching to an inactive screen or re-clicking the currently active screen)
- **THEN** the application SHALL activate the selected screen (or confirm the active screen)
- **AND** automatically dismiss the navigation drawer.

#### Scenario: Clicking action buttons in navigation drawer
- **WHEN** the pilot clicks the Flights, Edit Mode, or Settings action button in the open drawer
- **THEN** the application SHALL immediately trigger the corresponding screen or panel transition
- **AND** dismiss the navigation drawer without requiring multiple clicks.
