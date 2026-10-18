# Proposal: Autonomous Replay Testing Harness

## Why

Paragliding cockpit instruments and layout canvases must remain visually stable and bug-free across diverse mobile form factors, flight phases, and sensor edge cases. Currently, testing layout regressions or telemetry handling requires manual ad-hoc widget tests or slow manual verification; an autonomous replay testing harness empowers developers and AI agents to systematically pump real and synthetic flight scenarios through any layout configuration in seconds, asserting UI invariants and producing machine-readable regression reports.

## What Changes

- Introduce a headless `AutonomousReplayHarness` runner capable of driving time-stepped flight scenarios through configurable flight screens and layout canvases without requiring GPU emulators or physical devices.
- Define a structured scenario catalog (`steady_glide`, `thermal_climb`, `heavy_sink`, `airspace_alert`, `sensor_dropouts`, and `boundary_extremes`) combining time-series telemetry and state transitions.
- Implement an automated layout invariant engine verifying zero `RenderFlex` overflow errors, non-truncated formatting bounds (e.g. 4-digit altitudes, negative HAG, triple-digit speeds), and proper visual cue activations.
- Add structured JSON test reporting (`build/harness/replay_report.json`) and keyframe snapshot generation for effortless autonomous inspection by AI agents and CI workflows.
- Provide a standardized Flutter test command and test entry point (`test/harness/autonomous_replay_harness_test.dart`) supporting selective scenario, canvas, and layout filtering.

## Non-Goals

- Replacing physical device GPS/BLE hardware testing or field validation flights.
- Strict pixel-by-pixel golden image assertion (which is brittle across Flutter engine font rendering revisions and anti-aliasing changes); instead, the harness focuses on invariant checks, layout bounds, and optional milestone screenshots.
- Emulating full MapLibre GL GPU shaders in headless unit tests (vector maps run with mock/placeholder tile providers during headless test runs).

## Capabilities

### New Capabilities
- `autonomous-replay-harness`: Headless automated test harness and scenario driver that replays time-stepped flight situations across responsive canvases, verifies cockpit layout invariants, and generates structured execution reports.

### Modified Capabilities
<!-- None -->

## Impact

- **Affected Code**:
  - `apps/mobile/test/harness/`: New harness runner, scenario definitions, invariant checkers, and test suite.
  - `apps/mobile/lib/services/telemetry/`: Replay fixtures and synthetic generators exposed or adapted for deterministic time-stepped harness driving.
- **Dependencies**: No new external runtime dependencies; uses existing Flutter test framework (`flutter_test`), `dart:io`, `dart:ui`.
- **Safety Impact**: Significantly enhances flight safety by preventing instrument UI truncation, negative value parsing crashes, or layout clipping during high-stress flight maneuvers (e.g., sink alarms, airspace warnings).
- **Offline Impact**: Fully offline-capable and deterministic; requires no network access or external APIs.
- **Privacy Impact**: All bundled scenarios use synthetic telemetry or sanitized public flight samples (no private pilot logs).
- **Licensing Impact**: MIT-licensed, completely aligned with repository standards.
