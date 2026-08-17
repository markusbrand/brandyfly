# Specification: UI & Configurable Screens

## Requirements

### Requirement: [REQ-UI-003] Top-down navigation
The application SHALL provide a main navigation bar that is hidden by default, appears via swipe-down, has configurable opacity, contains Settings and Edit Mode buttons, and dismisses when tapped outside. The user SHALL be able to configure the Navigation Bar visual style from predefined mockup options, defaulting to Option 1.

#### Scenario: Opening and Closing Navigation
- **WHEN** the user swipes down from the top of the screen
- **THEN** the main navigation bar SHALL slide down smoothly with configurable translucency
- **AND WHEN** the user taps outside the navigation bar
- **THEN** the navigation bar SHALL slide up and disappear

### Requirement: [REQ-UI-004] User configurable screens
The application SHALL allow the user to freely configure screens, add new screens, remove screens, and edit the layout of widgets within those screens via an "Edit Mode". The user SHALL be able to configure the normal flight screen layout strategy and thermaling screen visual style from predefined mockup options, defaulting to Option 3 for both.

#### Scenario: Adding and Editing Widgets in Edit Mode
- **WHEN** the user enters Edit Mode via the navigation bar
- **THEN** widgets display layout handles and grid bounds
- **AND** the user can add new flight widgets, remove existing ones, and re-arrange their positions
