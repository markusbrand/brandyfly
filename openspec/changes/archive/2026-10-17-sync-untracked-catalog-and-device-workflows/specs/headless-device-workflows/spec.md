## MODIFIED Requirements

### Requirement: Execution target resolution
The system SHALL resolve the default run target based on the host environment and user invocation, supporting headless servers, physical connected devices, and local developer workstations across Linux and macOS.

#### Scenario: Default run command on headless server
- **WHEN** the user invokes the default run command on the headless development server
- **THEN** the system targets the GPU-accelerated Android emulator on the user's Garuda PC workstation or server emulator and ensures it is active before deploying

#### Scenario: Physical device run command on headless server
- **WHEN** the user requests running the app on a connected Android device on the headless server
- **THEN** the system defaults to checking for a physically connected USB device on the server and provides setup guidance if none is present

#### Scenario: Local GPU emulator targeting on Linux workstation
- **WHEN** the user runs the app on a local Linux desktop workstation
- **THEN** the system targets the local GPU-accelerated emulator instance (`brandyfly_test_device`)

#### Scenario: Local iOS Simulator targeting on macOS workstation
- **WHEN** the user runs the app on a macOS workstation
- **THEN** the system boots or activates the iOS Simulator via Xcode Device Hub and deploys the app with mock flight mode enabled
