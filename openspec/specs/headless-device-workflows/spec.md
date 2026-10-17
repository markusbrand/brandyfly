# headless-device-workflows Specification

## Purpose
Defines automated lifecycle management, streaming, and target selection for headless Android emulators and physical testing devices on Linux servers.

## Requirements

### Requirement: Headless emulator automated lifecycle
The system SHALL provide automated startup and shutdown of the Android emulator on headless servers with hardware-accelerated offscreen rendering and cold boot isolation.

#### Scenario: Headless server startup
- **WHEN** the startup script is executed on a headless Linux host
- **THEN** the emulator starts detached with host GPU rendering inside a virtual X11 display context without quick-boot snapshots

#### Scenario: Clean termination
- **WHEN** the shutdown script is executed
- **THEN** the emulator process and its network forwarding bridges terminate cleanly without leaving orphaned lock files

### Requirement: LAN ADB bridge forwarding
The headless server SHALL expose the local Android emulator ADB port on its local network interface to enable direct device mirroring on remote workstations.

#### Scenario: Workstation connects to server emulator
- **WHEN** an ADB client on a local network workstation connects to the server IP and port 5555
- **THEN** the connection succeeds and device mirroring tools stream the active Android screen with low latency

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

### Requirement: Autonomous visual inspection and input injection
The system SHALL support capturing screen buffers and injecting input events for autonomous validation.

#### Scenario: Visual UI capture
- **WHEN** an automated test or agent requests a screen capture from the active emulator
- **THEN** a valid PNG image of the running UI is generated for visual inspection

#### Scenario: Input event injection
- **WHEN** tap, swipe, or key events are sent via ADB
- **THEN** the active app responds to the corresponding user interactions
