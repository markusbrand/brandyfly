## Why

BrandyFly currently lacks a dedicated thermaling workflow that helps pilots quickly assess whether circling is producing net climb or sink. Adding an XCTrack-style thermaling view now improves in-flight decision support and aligns the app with a core capability pilots expect from modern variometer software.

## What Changes

- Detect thermaling behavior from live flight track patterns (circling) and vertical movement, then automatically transition to a dedicated thermaling screen when thermaling is recognized.
- Render circle markers at thermaling positions with polarity and size encoding:
  - Green circles for net uplift.
  - Red circles for net sink.
  - Circle size proportional to magnitude (stronger climb/sink yields larger circles).
- Add a dedicated thermaling screen that is independently configurable from the main flight screen.
- Add thermaling-screen-specific configuration for map/background layer and widget sets (for example uplift and wind-direction widgets), without coupling these settings to the main screen configuration.
- Keep the existing main screen behavior available and ensure pilots can still use it outside thermaling detection.

## Capabilities

### New Capabilities

- `flight/thermaling-detection-and-visualization`: Detect thermaling episodes from circling/uplift patterns and present circle overlays with color and size mapped to climb/sink magnitude.
- `ui/thermaling-screen-configuration`: Provide a separate thermaling screen with independently configurable map background and widget layout/settings.

### Modified Capabilities

- None.

## Non-Goals

- Introducing automated route guidance, tactical turn recommendations, or safety-critical autopilot-like advice.
- Replacing the main flight screen as the default UI for all flight phases.
- Adding cloud-dependent thermaling analytics; this feature remains usable with local flight data.

## Impact

- **Affected code/systems**: [apps/mobile/](/home/markus/Projects/brandyfly.worktrees/thermaling-feature-enhancement/apps/mobile), shared flight-state contracts in [packages/contracts/](/home/markus/Projects/brandyfly.worktrees/thermaling-feature-enhancement/packages/contracts), and potentially flight-core signal interfaces in [crates/flight_core/](/home/markus/Projects/brandyfly.worktrees/thermaling-feature-enhancement/crates/flight_core).
- **APIs/contracts**: New runtime state and events for thermaling detection and marker payloads between flight processing and UI layers.
- **Privacy**: No new personal data categories are introduced; the feature uses existing flight telemetry already handled by the app.
- **Safety**: Thermaling cues are advisory only and must not be presented as certified safety instrumentation or sole basis for flight decisions.
- **Offline**: Detection, rendering, and screen switching must function without network connectivity.
- **Licensing**: No new third-party data source is required by this proposal; existing map/data attribution requirements remain in effect.
