## ADDED Requirements

### Requirement: [REQ-SETTINGS-001] Settings Configuration
The application SHALL provide a Settings screen accessible from the main navigation to configure external Bluetooth devices, XContest accounts, UI preferences, license info, and app version. The user SHALL be able to configure the Settings screen visual style from predefined mockup options, defaulting to Option 2.

#### Scenario: Navigating to Settings
Given the user opens the main navigation bar
When the user taps the settings icon
Then the Settings screen SHALL be displayed
When the user dismisses the Settings screen
Then the application SHALL return to the previously active screen

### Requirement: [REQ-SETTINGS-002] Localization
The application SHALL support switching languages from the Settings screen, initially supporting English and German.

#### Scenario: Switching to German
Given the application is running in English
When the user selects German in the Settings screen
Then the application UI SHALL immediately update to display German text

### Requirement: [REQ-SETTINGS-003] Theme Mode
The application SHALL support switching between light and dark modes.

#### Scenario: Toggling Dark Mode
Given the application is in Light mode
When the user toggles Dark mode in the Settings screen
Then the application UI SHALL update to use the dark theme colors
