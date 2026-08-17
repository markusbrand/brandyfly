## Why

The current BrandyFly mobile interface uses a basic developer/demo scaffold that lacks flight ergonomics, high-visibility telemetry visuals, and modern UI design standards. Paragliding flight cockpits require rapid readability under direct sunlight, glove-friendly touch targets, dynamic visual feedback for climb/sink rates, and flexible telemetry view modes. Applying advanced frontend design principles will transform BrandyFly into a state-of-the-art, visually captivating, and ergonomic vario application.

## What Changes

- **UI Design System**: Introduce a dedicated cockpit design system featuring high-contrast dark/sunlight color schemes, dynamic gradients, blur/glassmorphism telemetry overlays, modern typography hierarchy (Inter/Roboto Mono aesthetic), and standardized spatial tokens.
- **Flight Dashboard & Vario Instrument**: Re-architect the vario gauge into a fluid, animated instrument with high-visibility climb/sink arcs, dynamic color accents, thermal indicator ring, and numeric telemetry hierarchy.
- **Multi-Layout Cockpit Modes**: Support seamless switching between specialized views:
  - *Thermal / Climb View*: Emphasizes vertical speed (vario), thermal gradient, altitude MSL, and instantaneous climb/sink trend lines.
  - *Cruise / XC View*: Focuses on ground speed, glide ratio, wind vectors, waypoint/distance indicators, and sparkline altitude profiling.
  - *Compact / Mounted Split View*: Adaptive grid layout tailored for side-by-side or stacked orientation on flight decks and tablets.
- **Glove-Friendly Ergonomics**: Expand interactive touch targets (minimum 48dp), add visual button elevation/feedback, and optimize gesture controls for cockpit operations.
- **Micro-Animations & Visual State**: Add responsive micro-animations for altitude trends, state transitions, simulated flight playback controls, and mode chips.

## Capabilities

### New Capabilities

- `cockpit-ui-ux`: Modern cockpit design system, animated vario gauges, high-visibility adaptive telemetry dashboards, and ergonomic pilot interaction modes.

### Modified Capabilities

(None)

## Impact

- **Mobile App (`apps/mobile/lib`)**: Complete UI refactoring of main views, themes, dashboard widgets, vario displays, and navigation/mode structures.
- **Dependencies**: No breaking native contracts or core Rust flight core API modifications required; hot sensor and audio telemetry paths remain decoupled from UI rendering threads.
