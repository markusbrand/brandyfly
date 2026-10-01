## Why

The 8-column flight canvas makes the smallest widget a tall, narrow strip (about 49 x 105 dp on a phone), so pilots cannot build dense cockpits. Map zoom and recenter buttons are hard-wired into the map widget at 28 dp, below glove-friendly touch size, and cannot be moved. In addition, every telemetry tick rebuilds the entire canvas including edit chrome, and the layout code mixes persistence, layout rules and rendering in one service. This makes the planned features hard to add safely.

## What Changes

- **BREAKING (persisted data, auto-migrated)**: The flight canvas grid moves from 8 dynamic-height columns to a fixed 16-column x 32-row virtual grid that always fills the canvas without scrolling. Saved layouts (4-column and 8-column) are migrated proportionally on load.
- Each flight screen MAY store an optional second layout variant for wide canvases (canvas width > height). Screens without a wide variant render their tall layout stretched.
- Instrument widgets switch between three content tiers (tiny, compact, regular) based on their rendered pixel size, so 1-cell widgets stay legible.
- A widget catalog defines minimum, default and preset sizes per widget type. All editing paths (drag, steppers, inspector, config dialog) enforce the same rules.
- New placeable widgets: **Map Zoom In**, **Map Zoom Out**, **Map Recenter** and **Map Zoom Rocker**. Each targets a specific map widget or the first map on the screen and reflects that map's state (centered, zoom limits).
- Map widgets gain a "built-in controls" option: Auto (hidden when external controls target the map), Always or Never.
- Edit mode gains size presets (S/M/L/Full), outside-the-frame resize handles, alignment snapping guides, overlap highlighting, a live tier hint, and a Tall/Wide variant toggle.
- Editing toolbars and the inspector reflow responsively (wrap or icon-only) instead of being shrunk by `FittedBox`.
- Telemetry is delivered as a typed snapshot. Each instrument rebuilds only when its own field changes, and edit chrome never rebuilds on telemetry.
- The touched UI slices are restructured into layered UI / domain / data architecture (view models, layout-editing use case, layout and telemetry repositories) with `provider`-based dependency injection.
- New automated coverage: grid migration and rule unit tests, an overflow sweep across all widget types, styles, tiers and three canvas sizes, map-control widget tests, a rebuild-count performance test, and an end-to-end `integration_test` walkthrough.

### Non-goals

- No free-form (non-grid) positioning.
- No external zoom or recenter controls for the thermal map. It keeps its built-in controls; this may follow later.
- No changes to the Rust flight core, sensor or audio paths, telemetry sources, or replay determinism.
- No full-app folder restructure. Untouched modules (tracking, storage, XContest, tile server, PMTiles, settings, flights screen) stay where they are for a follow-up change, to avoid conflicts with in-flight changes.
- No new map styles, layers or data sources.
- No freezed or other code generation.

## Capabilities

### New Capabilities

- `map-control-widgets`: Placeable zoom-in, zoom-out, recenter and zoom-rocker widgets that drive a target map's camera, reflect its state, and manage built-in map control visibility.
- `responsive-flight-canvas`: Fixed 16x32 virtual grid, tall and wide layout variants, size-tier content rendering, touch-target minimums, and layout-error-free rendering across canvas sizes.
- `layered-ui-architecture`: Separation of flight canvas and layout editing into view, view-model, domain-rule and repository responsibilities with injected dependencies and independently testable units.

### Modified Capabilities

- `screen-widget-configuration`: Grid bounds move from 8 columns to 16x32, the legacy migration is extended, editing gains presets, snapping and catalog-enforced minimums, and the canvas no longer scrolls.
- `center-glider-map-with-auto-recenter`: Recenter and zoom can be triggered by external control widgets with the same semantics as the built-in buttons.
- `ui-performance-optimization`: Telemetry rebuilds are scoped per field, edit chrome is isolated from telemetry, and grid guides are painted in a single layer.

## Impact

- **Code**: `apps/mobile/lib/models/ui_config.dart`, `services/screen_manager_service.dart`, `services/ui_persistence_service.dart`, `widgets/layout/*`, `widgets/flight/map_widget.dart`, the instrument widgets, and `main.dart` wiring. New `lib/data`, `lib/domain` and `lib/ui` slices.
- **Dependencies**: adds `provider` (MIT) and the `integration_test` dev dependency (Flutter SDK). Bundles the Barlow Semi Condensed font (SIL OFL 1.1), recorded in `THIRD_PARTY_DATA.md`.
- **Persisted data**: the UI config gains a `schemaVersion` field and is migrated on load. The original JSON is kept as a backup key, so a failed migration falls back to the default layout without data loss.
- **Safety**: a misconfigured or targetless map control is inert and visibly dimmed and never crashes. Flight instruments stay full-screen with no scrolling. Touch targets for map controls are at least 48 dp.
- **Offline**: no network dependency is introduced. The font is bundled.
- **Privacy**: no new data collection.
- **Tests**: existing 217 tests must stay green; selectors that rely on 8-column bounds are updated.
