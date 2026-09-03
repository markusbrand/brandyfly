## ADDED Requirements

### Requirement: [REQ-UI-001] Launch screen restoration
The application SHALL restore the last active screen upon launch, unless the last active screen was the thermaling screen.

#### Scenario: Normal App Launch
Given the user previously closed the app while viewing the "Map" screen
When the application is launched
Then the "Map" screen SHALL be displayed

### Requirement: [REQ-UI-002] Thermaling screen auto-transition
The application SHALL automatically display the "thermaling screen" when the pilot starts circling in thermal air, and revert to the previous screen when the pilot continues to fly straight.

#### Scenario: Entering and Exiting a Thermal
Given the user is on the "Map" screen
When the flight core detects circling in thermal air
Then the "thermaling screen" SHALL be displayed
When the flight core detects straight flight
Then the "Map" screen SHALL be restored

### Requirement: [REQ-UI-003] Top-down navigation
The application SHALL provide a main navigation bar that is hidden by default, appears via swipe-down, has configurable opacity, contains Settings and Edit Mode buttons, and dismisses when tapped outside. The user SHALL be able to configure the Navigation Bar visual style from predefined mockup options, defaulting to Option 1.

#### Scenario: Opening and Closing Navigation
Given the main navigation bar is hidden
When the user swipes down from the top edge
Then the navigation bar SHALL appear
When the user taps outside the navigation bar
Then the navigation bar SHALL disappear

### Requirement: [REQ-UI-004] User configurable screens
The application SHALL allow the user to freely configure screens, add new screens, remove screens, and edit the layout of widgets within those screens via an "Edit Mode". The user SHALL be able to configure the normal flight screen layout strategy and thermaling screen visual style from predefined mockup options, defaulting to Option 3 for both.

#### Scenario: Adding a Screen
Given the user is in Edit Mode
When the user selects to add a new screen
Then a new configurable screen SHALL be created

### Requirement: [REQ-UI-005] Widget configuration
The application SHALL allow widgets to be resized, positioned, colored (dark/light), set with varying transparency, and ordered (z-index) on the screen. These configurations SHALL be persistent.

#### Scenario: Modifying a Widget
Given the user is in Edit Mode on a screen with an Altitude widget
When the user moves the widget and changes its transparency
Then the changes SHALL be visually reflected immediately and persisted across app restarts
