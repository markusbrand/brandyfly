## 1. Application Shell and Route Model

- [ ] 1.1 Introduce root route state for Flight Deck, Screen Configuration, and Settings without coupling it to flight-page selection
- [ ] 1.2 Move existing live and simulated runtime providers beneath the shared shell while preserving startup/loading/error behavior
- [ ] 1.3 Render persistent simulated-flight labeling in shared Flight Deck chrome and keep mock activation controls excluded from production builds
- [ ] 1.4 Add shell tests for initial Landing Page routing, live/simulated provider selection, production mock exclusion, and navigation without flight-provider restart

## 2. Versioned Local Configuration

- [ ] 2.1 Define versioned page configuration models for page roles/order, stable widget instances, layouts, and per-page map settings
- [ ] 2.2 Define a separate versioned global-preferences model for theme mode, locale, and metric/imperial units
- [ ] 2.3 Implement independent repositories, validation, migrations, and local offline persistence for page and preference documents
- [ ] 2.4 Add safe fallback generation that preserves valid documents independently and always restores one Landing Page and one Thermaling Screen
- [ ] 2.5 Add unit tests for corrupt/missing data, schema migration, restart persistence, and isolation between page and global-preference failures

## 3. Extensible Widget Registry and Data State

- [ ] 3.1 Define stable widget descriptors with localized metadata, data contracts, configuration versions, default sizes, renderers, and stale/unavailable policies
- [ ] 3.2 Register the essential altitude, vario, ground-speed, glide-ratio, flight-time, current-time, wind-direction, wind-strength, map, and sensor-status widgets
- [ ] 3.3 Adapt existing demo altitude/vario/speed/glide presentation to canonical flight snapshots and registry-backed widgets
- [ ] 3.4 Preserve unknown widget instances across load/save and render a non-destructive unavailable placeholder
- [ ] 3.5 Add widget tests for registration, future widget addition without layout migration, current/stale/unavailable states, and unavailable wind/device sources

## 4. Page Management and Configuration Experience

- [ ] 4.1 Implement create, rename, reorder, configure, and delete operations for user-created normal pages
- [ ] 4.2 Enforce singleton Landing Page/Thermaling Screen roles and reject deletion or duplicate required-role configurations
- [ ] 4.3 Implement page-scoped widget add/remove/arrange/configure operations and configuration previews
- [ ] 4.4 Add page selector behavior that includes Thermaling Screen for configuration but excludes it from manual Flight Deck paging
- [ ] 4.5 Add UI/domain tests for page lifecycle operations, per-page configuration isolation, required-role invariants, and offline restart restoration

## 5. Flight Deck Navigation and Thermaling Override

- [ ] 5.1 Implement horizontal paging through Landing Page and user-created normal pages with deterministic ordering and dominant-axis gesture handling
- [ ] 5.2 Track `lastManualPageId` independently from the effective visible Flight Deck page
- [ ] 5.3 Consume the existing thermaling-state signal to activate Thermaling Screen and restore the last manual page when thermaling ends
- [ ] 5.4 Keep Settings/Screen Configuration foreground routes stable while thermaling state changes and resolve the correct effective page on return
- [ ] 5.5 Add state-machine and gesture tests for startup, swiping, thermaling enter/exit, route interruptions, lifecycle resume, and gesture-axis conflicts

## 6. Main Navigation and Global Preferences

- [ ] 6.1 Implement the shared semi-transparent top navigation overlay with top-down reveal and outside-tap dismissal on every application-shell route
- [ ] 6.2 Connect Flight Deck, Screen Configuration, and Settings actions and verify current/effective page selection on each transition
- [ ] 6.3 Implement Settings controls for system/light/dark appearance, supported language selection, and metric/imperial units
- [ ] 6.4 Apply theme and locale at the shell boundary and apply unit conversion/formatting only in built-in widgets and previews while preserving canonical source values
- [ ] 6.5 Add navigation/settings tests for every shell route, persistence while offline, translation fallback, immediate theme changes, and consistent built-in widget units

## 7. Bluetooth Device Settings and Sensor Status

- [ ] 7.1 Define a Flutter-facing device-capability contract for platform-supported device families, permissions, discovery, connection lifecycle, staleness, and internal-sensor fallback
- [ ] 7.2 Implement Settings UI for discover/connect/disconnect/reconnect and explicit permission-denied, unsupported, stale, and disconnected states
- [ ] 7.3 Gate connectable production devices on adopted platform validation results and do not expose the SkyDrop validation prototype as production support
- [ ] 7.4 Bind the sensor-status widget to normalized active-source state without routing sensor samples or Bluetooth callbacks through render state
- [ ] 7.5 Add contract/UI tests for supported and unsupported platforms, permission denial, reconnect, stale/disconnected devices, internal-sensor fallback, and non-blocking navigation

## 8. Governed Map Configuration

- [ ] 8.1 Define the UI-facing approved map-source catalogue contract with availability, offline/caching approval, attribution, review state, and engine/package compatibility
- [ ] 8.2 Populate selectable sources only from approved catalogue entries compatible with the map engine selected by the offline-map benchmark
- [ ] 8.3 Implement per-page source selection and independent flight-zone, flown-track, and planned-track overlays with required attribution
- [ ] 8.4 Implement explicit missing/corrupt/unavailable map state and approved local fallback behavior without transparent online substitution
- [ ] 8.5 Decouple/debounce map configuration changes from high-frequency widget updates and retain non-map widget interaction during map failure
- [ ] 8.6 Add tests for blocked/expired/unapproved sources, attribution, overlay independence, offline failure/fallback, and map-update isolation

## 9. End-to-End Validation and Rollout

- [ ] 9.1 Add an integration flow covering startup on Landing Page, page creation/configuration, manual swiping, thermaling takeover/restore, Settings interruption, and app restart
- [ ] 9.2 Run the same shell/page flow in local mock mode and verify deterministic synthetic providers plus persistent simulation labeling
- [ ] 9.3 Validate offline operation for navigation, layouts, global preferences, internal-sensor fallback, and installed approved map data
- [ ] 9.4 Profile widget/page/map updates on supported Android and iOS targets and verify UI work causes no regression in existing sensor/audio responsiveness gates
- [ ] 9.5 Run targeted Flutter/domain/platform test suites and `openspec validate add-configurable-flight-screens --type change --strict`
- [ ] 9.6 Document feature-flag rollout/rollback behavior so legacy view selection can be restored without deleting versioned page or preference data
