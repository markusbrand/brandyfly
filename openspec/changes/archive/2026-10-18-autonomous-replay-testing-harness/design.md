# Design: Autonomous Replay Testing Harness

## Context

BrandyFly renders dynamic flight instruments across customizable screens and diverse device canvases (phones in portrait and landscape, tablets). While isolated widget unit tests exist (`overflow_sweep_test.dart`) and static single-frame captures exist (`screenshot_review_test.dart`), there is no unified mechanism to pump active flight progressions through the live cockpit layouts to verify that instrument numbers, color indicators, alarms, and widgets do not cause layout overflows or state crashes.

See `proposal.md` for motivation and background.

## Goals / Non-Goals

**Goals:**
- Provide an ultra-fast in-process headless test runner (`flutter test test/harness/autonomous_replay_harness_test.dart`) executing in ~3–5 seconds.
- Support deterministic time-stepped replay of standard paragliding scenarios (`steady_glide`, `thermal_climb`, `heavy_sink`, `airspace_alert`, `sensor_dropouts`, `boundary_extremes`).
- Run scenarios across the core responsive canvas matrix: phone portrait (`390x844`), phone landscape (`844x390`), and tablet landscape (`1280x800`).
- Intercept and record all `RenderFlex` overflow errors and render exceptions across the entire matrix.
- Generate a machine-readable JSON report (`build/harness/replay_report.json`) detailing execution status, tested canvases, error stack traces, and artifact locations for AI agent and CI consumption.
- Support optional milestone screenshot generation via `SCREENSHOTS=1`.

**Non-Goals:**
- Pixel-by-pixel golden image diffing (fragile across Flutter rendering versions).
- Headless emulation of MapLibre GL GPU shaders (maps use mock backdrops or placeholder tiles in headless mode).
- Hardware Bluetooth or physical sensor simulation.

## Decisions

### 1. In-Process Headless Widget Testing vs. Target Emulator
- **Choice**: Pure in-process headless testing using Flutter's `WidgetTester`.
- **Rationale**: Headless tests run in seconds on any CI runner or development worktree without needing an Android emulator, GPU acceleration, or ADB bridge. This makes it ideal for fast inner-loop verification by autonomous AI agents and developers before committing code.
- **Alternatives Considered**: Headless emulator testing (`deploy-garuda-emulator.sh` / ADB). While closer to production hardware, emulator launch and APK deployment add 30–60+ seconds of latency per check, making rapid iterative feedback impractical.

### 2. Declarative Scenario Catalog
- **Choice**: Declarative `ReplayScenario` objects with discrete time-stepped milestones and invariant assertions.
- **Rationale**: Decouples scenario generation from UI rendering. Scenarios define a sequence of `TelemetrySnapshot` states (or `CockpitTelemetry`), milestone names (e.g. `entry`, `peak_climb`, `sink_alarm`), and expected invariant conditions.
- **Alternatives Considered**: Streaming raw IGC files with real-time delays. This introduces unnecessary wall-clock delays and disk I/O; deterministic simulated time stepping allows complete multi-minute flights to be verified in milliseconds.

### 3. Non-Aborting Invariant Error Collector
- **Choice**: Wrap test scenario runs in a custom `FlutterError.onError` collector that accumulates all layout overflow violations across all screens and canvases without crashing the test runner prematurely.
- **Rationale**: When an AI agent modifies layout widgets, having a comprehensive list of all affected canvas orientations and scenarios in one report enables immediate targeted fixes, rather than fixing one error only to crash on the next orientation.
- **Alternatives Considered**: Default Flutter test error handler (aborts on first `RenderFlex` overflow).

### 4. Structured JSON Report for Agentic Velocity
- **Choice**: Output a standardized `build/harness/replay_report.json`.
- **Rationale**: Enables AI agents to read a single file after running `flutter test` to programmatically determine whether regressions occurred, which exact widgets overflowed, and which canvases failed.
- **Structure**:
  ```json
  {
    "timestamp": "2026-10-18T20:00:00Z",
    "passed": true,
    "scenarios_evaluated": 6,
    "canvas_tested": ["phone_portrait", "phone_landscape", "tablet_landscape"],
    "failures": [],
    "milestones": [
      {
        "scenario": "thermal_climb",
        "canvas": "phone_portrait",
        "milestone": "peak",
        "screenshot": "build/harness/screenshots/thermal_climb_phone_portrait_peak.png"
      }
    ]
  }
  ```

## Risks / Trade-offs

- **[Risk] Headless font metrics differing from target devices** → **Mitigation**: Load bundled Roboto and BarlowSemiCondensed fonts during harness setup (reusing `_loadFonts` from `screenshot_review_test.dart`) to ensure accurate text dimensions.
- **[Risk] Map widget dependencies in headless tests** → **Mitigation**: Mock `MapLibre` native channel calls or provide placeholder canvas backdrops so layouts containing map elements can be exercised without native libraries.
- **[Risk] Combinatorial test execution time explosion** → **Mitigation**: Focus the matrix on 3 key canvases $\times$ 6 core flight scenarios $\times$ default cockpit screens, keeping execution under 5 seconds.
