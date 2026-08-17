## Context

See `proposal.md` for motivation and `specs/flight-screen-configuration/spec.md` for behavioral requirements. The current Flutter entry point directly selects separate live or simulated views, fixes the app to dark mode, and the demo vario formats metric values in its widgets. The completed mock-flight change requires production exclusion and persistent simulation labeling; the open Bluetooth, map-engine, and data-source changes deliberately gate what transports, engines, and sources can be claimed. This design must introduce the shared shell without bypassing those gates or coupling safety-critical telemetry/audio to UI thread timing.

## Goals / Non-Goals

**Goals:**

- Introduce a unified in-flight page model that supports Landing, Thermaling, and user-created normal pages.
- Replace separate top-level live/simulated screens with one application shell and explicit route state.
- Keep manual navigation deterministic (swipe only through normal pages) while allowing automatic thermaling takeover and restore.
- Add a global navigation bar interaction that is consistent across all app screens.
- Separate application-wide preferences and device connections from page-scoped layout/map configuration.
- Make the initial widget set extensible while preserving stable persisted page definitions.

**Non-Goals:**

- Changing thermaling detection algorithms or threshold tuning in the flight core.
- Adding cloud synchronization/import/export of layouts.
- Implementing Bluetooth protocols, selecting a map engine, or approving map/data providers in this change.
- Converting canonical flight-core values to user-selected units before they reach the presentation layer.

## Decisions

### Use explicit page roles with one automatic role

Persist each page with a role enum:
- `landing` (singleton normal page)
- `normal` (0..n user pages)
- `thermaling` (singleton automatic page)

Navigation logic treats `landing` and `normal` as swipeable and excludes `thermaling` from manual page lists. This provides a clean contract and avoids brittle special-case checks by page name.

Alternative: keep all pages in one list with per-page boolean flags (`isThermaling`, `isDefault`). Rejected because multiple independent booleans permit invalid states (multiple defaults, thermaling page in swipe list) and complicate validation.

### Separate application route state from flight-page state

The root application shell owns a small route model (`flightDeck`, `screenConfiguration`, `settings`) plus the shared top overlay. The Flight Deck owns page selection separately. Thermaling events update only Flight Deck state; they never replace the root route. Returning from Settings/configuration resolves the effective page from current thermaling state and `lastManualPageId`.

Loading and fatal bootstrap failures remain outside the interactive shell until startup succeeds. Live and simulated runtime providers are injected beneath the same shell, with the simulated marker rendered by the Flight Deck chrome rather than by an independent page.

Alternative: use thermaling and global navigation to push/pop all routes on one navigator stack. Rejected because a flight-state event could unexpectedly dismiss Settings/configuration and because route history would become coupled to high-frequency flight state.

### Split page selection into manual and automatic selectors

Maintain two selectors:
- `lastManualPageId` (updated by swipe/tap page changes on normal pages)
- `effectiveVisiblePageId` (manual page unless thermaling override active)

When thermaling starts, switch `effectiveVisiblePageId` to thermaling page and preserve `lastManualPageId`. When thermaling ends, restore `effectiveVisiblePageId` from `lastManualPageId`.

Alternative: replace current page directly on thermaling start and store ad-hoc previous page references in transient UI state. Rejected because app lifecycle interruptions (pause/resume/restart) can lose transient references and create incorrect restore behavior.

### Store page configuration and global preferences in separate versioned schemas

Use a versioned page configuration document containing:
- page registry (id, role, order, title)
- per-page widget instances (stable widget type id, layout, widget settings)
- per-page map config (source and overlays)

Use a separate versioned global-preferences document containing theme mode, locale, and unit system. Device connection preferences store only safe reconnect metadata and references to platform-supported device identities; transient permission, stale, and connection state stays in the device service.

Load both documents with independent validation and migration. On invalid/missing page config, generate safe page defaults. On invalid global preferences, fall back independently to system theme, default locale, and metric units so one corrupt preference cannot discard page layouts.

Alternative: persist pages, preferences, and device state in one document. Rejected because unrelated migration/failure domains would be coupled and transient Bluetooth state could corrupt durable UI configuration.

### Register widgets through stable descriptors

Each widget type supplies a stable id, localized display metadata, supported data contract, configuration schema/version, default size, renderer, and stale/unavailable policy. Page documents store only the stable type id and versioned instance configuration. Unknown widget types are retained but rendered as unavailable placeholders so a downgrade or optional module does not destroy layout data.

The initial registry contains altitude, vario, ground speed, glide ratio, flight duration, clock, wind direction/strength, map, and sensor/connection status. Flight data remains in canonical SI/domain units; the presentation formatter applies metric/imperial settings and localized labels at render time.

Alternative: encode every widget as a closed enum with layout-specific fields. Rejected because every new widget would require central model migrations and would make long-lived user layouts fragile.

### Route global top bar through a shared overlay controller

Implement top-down reveal/hide behavior via a centralized overlay controller that can be mounted by the root flight shell and reused by other screens. The controller owns visibility, gesture entry, outside-tap dismissal, and action callbacks (open screen config, open settings).

Alternative: add independent top bar widgets per screen. Rejected because it risks behavior drift, duplicated gesture handling, and inconsistent dismissal behavior.

### Expose Bluetooth settings through validated capability contracts

Settings consumes a platform device-capability service that reports supported transport/device families, permission state, discoveries, connection lifecycle, staleness, and internal-sensor fallback. A device appears connectable only when a production implementation has adopted evidence from the relevant validation change for that platform. The current SkyDrop validation prototype is therefore not promoted automatically.

The sensor-status widget consumes normalized source state, not Bluetooth callbacks, so internal and future external sources share current/stale/unavailable presentation. Discovery/connection runs asynchronously outside Flutter's render path, and sensor samples continue through native/Rust boundaries rather than through Settings UI state.

Alternative: have Settings scan and parse devices directly in Dart. Rejected because it bypasses platform support boundaries, couples UI lifecycle to transport state, and risks sensor latency/reconnect behavior.

### Consume governed map capabilities rather than define providers here

The map settings UI reads an approved source catalogue whose entries include availability, offline/caching permission, attribution, review state, and compatible package/engine metadata. It uses the engine selected by the offline-map benchmark. Missing/corrupt local data produces explicit unavailable state or a preconfigured approved local fallback; there is no transparent online substitution.

Alternative: hard-code provider URLs and fallback chains in page configuration. Rejected because it would bypass licensing governance and make expired/revoked providers difficult to remove safely.

### Keep heavy map updates decoupled from high-frequency flight metrics

Map source and overlay changes are low-frequency configuration events, while flight metrics are higher-frequency data updates. The rendering layer should apply map configuration updates through debounced state changes so widget metric refresh and map style/network activity do not contend unnecessarily.

Alternative: rebuild complete page tree on any metric or map config change. Rejected due to avoidable frame churn, higher battery cost, and increased risk of jank on older devices.

### Apply theme, locale, and units at application-shell boundaries

Theme mode and locale are root-shell inputs so Settings changes update built-in routes consistently. Unit formatting is injected into widgets and previews; canonical values in flight snapshots and persisted tracks remain unchanged. Widget repaint scopes isolate preference updates from native sensor/audio processing.

Alternative: convert values in the native/Rust source when unit settings change. Rejected because it mixes presentation preference with domain contracts, complicates tests, and risks inconsistent calculations.

## Risks / Trade-offs

- [Gesture conflicts between horizontal page swipes and vertical top-bar reveal] -> Define directional gesture thresholds and prioritize dominant axis before triggering navigation.
- [Auto thermaling switch could feel abrupt during user interactions] -> Keep transitions immediate but animate predictably and preserve `lastManualPageId` so exiting thermal always restores expected context.
- [Invalid persisted configuration can break startup] -> Enforce schema validation with safe fallback generation for required singleton pages and explicit migration paths.
- [Unsupported Bluetooth options could imply unsafe device support] -> Derive options from platform capability records and retain visible internal-sensor fallback.
- [Map source choices may vary by platform, license, or installed data] -> Resolve through the approved catalogue, preserve attribution, and keep overlays/non-map widgets independent.
- [Unknown widget ids appear after downgrade/module removal] -> Preserve instance data and show an unavailable placeholder rather than dropping the widget.
- [Changing units can trigger broad widget rebuilds] -> Keep canonical snapshots stable and scope formatter/theme/locale dependencies to presentation subtrees.
- [Battery impact from configurable rich layouts] -> Constrain refresh rates for non-critical widgets and avoid full-page rebuilds on every telemetry tick.

## Migration Plan

1. Wrap the existing live and simulated views in the root shell while preserving current startup/error handling and simulation markers.
2. Introduce independent versioned page and global-preference stores with safe defaults; adapt the hardcoded dark theme and metric demo through those stores.
3. Add widget descriptors and migrate the existing demo altitude/vario/speed/glide presentation into initial registry widgets.
4. Integrate manual multi-page navigation and thermaling override state without changing root routes.
5. Add shared top navigation, screen configuration, and Settings routes.
6. Wire Settings to supported device capability contracts and to theme/locale/unit presentation; do not promote validation-only transports.
7. Enable only governed map catalogue entries after map engine/source prerequisites are available; show explicit unavailable state beforehand.
8. Roll out behind a feature flag if available; rollback returns to the legacy view selection while preserving versioned settings/layout documents for later retry.
