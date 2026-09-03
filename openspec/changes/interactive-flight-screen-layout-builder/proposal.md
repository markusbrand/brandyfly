## Why

Flight dashboards in free flight (paragliding and hang gliding) require instant readability and intuitive ergonomics across varying cockpit setups—from smartphone cockpits mounted on flight decks to full-sized landscape tablets on competition harnesses. Pilots need distinct instrument configurations tailored to specific flight phases (such as tight thermal circling, cross-country glides, or airspace avoidance). 

Currently, widget layout adjustments are limited and lack fine-grained, direct visual canvas manipulation. Providing an interactive drag-and-drop builder with snapping fractional grids, cell constraint enforcement, collision highlights, and seamless inter-device sharing (via QR code and clipboard) empowers pilots to build, test, and share custom screen configurations effortlessly.

## What Changes

- **Fractional Grid System**:
  - Implement an 8x8 fractional grid container for portrait orientation and a 12x8 fractional grid container for landscape/tablet orientations in `apps/mobile`.
  - Enforce minimum cell constraints per widget type (e.g., Vario Bar min: 1x4, Speed/Altitude min: 2x1, Map/Thermal Map min: 4x4, Altitude Sparkline min: 4x2, Wind Indicator min: 2x2).
- **Interactive Edit Mode Canvas**:
  - Activate edit mode via long press on any instrument widget or an edit button in the navigation bar.
  - Support drag-to-move with tactile feedback, corner/pinch resizing handles, and dedicated swap handles.
  - Render real-time visual feedback for overlapping collisions (red translucent overlay) and valid snapping boundaries (green/cyan grid line snap targets).
- **Profile Layout Contract Specification**:
  - Define a formal JSON schema in `packages/contracts` for screen layout profiles, widget coordinate models, minimum bounds, and styling metadata.
  - Implement validation fixtures and serialization models across Rust (`packages/contracts`) and Dart (`apps/mobile`).
- **Cross-Device Profile Sharing**:
  - Enable instantaneous profile and screen export/import via compressed QR code generation/scanning and system clipboard JSON.

## Capabilities

- **Responsive Grid Engine**: Automatically maps widget fractional cells to actual physical screen coordinates across phone and tablet aspect ratios.
- **Direct Visual Editing**: Intuitive on-screen manipulation with responsive drag, corner resize, and widget swap interactions.
- **Conflict Prevention**: Visual collision highlights and intelligent coordinate clamping preventing widgets from overlapping or overflowing screen boundaries.
- **Peer-to-Peer Layout Exchange**: Pilots can scan another pilot's screen QR code at takeoff or paste a shared configuration from messaging apps to adopt a flight dashboard immediately.

## Non-Goals

- Remote server synchronization or online user accounts for layout hosting (offline-first design principle).
- Dynamic third-party runtime plugin scripting for widget code.
- Multi-finger freeform rotation of instrument widgets (layouts remain strictly grid-aligned).

## Impact

- `apps/mobile`: Updates to `ScreenManagerService`, `FlightScreenModel`, `WidgetPlacementModel`, and layout rendering views; adds interactive edit canvas and QR export/import UI.
- `packages/contracts`: Standardized Rust and JSON schema data models and contract test fixtures.
