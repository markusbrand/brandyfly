# autonomous-replay-harness Specification

## Purpose
Provides a headless automated replay testing harness that drives flight scenarios across responsive canvases and cockpit layouts, asserting invariant safety and producing machine-readable regression reports.

## Requirements

### Requirement: Automated Scenario Playback
The harness SHALL replay defined time-stepped flight situations (including steady glide, thermal climb, sink recovery, airspace warning, and sensor dropouts) through configurable cockpit screens without requiring an active emulator or physical device.

#### Scenario: Replay execution across flight phases
- **WHEN** the harness executes a flight scenario
- **THEN** time-stepped telemetry snapshots are pumped sequentially into the active screen layout at discrete simulated intervals.

### Requirement: Responsive Canvas Matrix Verification
The harness SHALL evaluate cockpit layouts across configured target canvases, including standard phone portrait, phone landscape, and tablet orientations.

#### Scenario: Canvas orientation matrix verification
- **WHEN** a test scenario runs across the canvas matrix
- **THEN** each screen layout is rendered and pumped on every designated screen dimension.

### Requirement: Layout Invariant and Overflow Assertion
The harness SHALL detect and report any layout bounds violations, including RenderFlex overflow exceptions, negative dimension constraints, and text clipping on extreme telemetry values.

#### Scenario: Extreme telemetry values without overflow
- **WHEN** extreme telemetry values (such as four-digit altitudes, negative HAG, or triple-digit speeds) are replayed
- **THEN** all flight canvas widgets render within their allocated bounds without throwing RenderFlex overflow exceptions.

#### Scenario: Sensor disconnection handling
- **WHEN** telemetry is marked as stale or disconnected during scenario replay
- **THEN** the layout updates to stale indicators without crashing or throwing render exceptions.

### Requirement: Structured Machine-Readable Test Reporting
The harness SHALL generate a structured JSON test execution report detailing tested scenarios, canvas configurations, pass/fail status, detected invariant errors, and milestone artifact paths.

#### Scenario: Report file generation
- **WHEN** the harness test suite completes
- **THEN** a structured JSON file is written to the test build directory containing complete regression evidence for AI agents and CI workflows.

### Requirement: Milestone Keyframe Artifact Capture
The harness SHALL support capturing visual milestone keyframes as PNG images for visual review when opted in via configuration or environment flags.

#### Scenario: Milestone keyframe capture
- **WHEN** milestone keyframe capture is enabled
- **THEN** representative milestone screenshots of critical flight states are exported to the artifact directory.
