## Why

BrandyFly needs one coherent application shell so pilots can reach flight pages, page configuration, and global settings predictably without disrupting safety-critical flight information. This change establishes that primary navigation and adds configurable flight screens comparable to XCTrack, including automatic landing and thermaling behavior.

## What Changes

- Add the application shell and primary navigation flow shared by live flight, simulated flight, page configuration, and settings screens.
- Add a configurable multi-page flight UI model backed by an extensible widget registry so additional widget types can be introduced without changing the page model.
- Ship an essential initial widget set: altitude, uplift/downlift vario, ground speed, lift-to-drag ratio, flight time, current time, wind direction, wind strength, map, and active sensor/connection status.
- Add a dedicated landing page that opens automatically when the app starts.
- Add a dedicated thermaling screen that is not part of manual page swiping and appears automatically when circling in lift; when thermaling ends, restore the last manually active page.
- Add support for user-created additional pages with the same widget and map configuration options as the landing page.
- Add gesture-driven page navigation while flying (horizontal swipe between normal pages).
- Add a global top-down swipe navigation bar (semi-transparent, top anchored) available throughout the application shell, with actions for the flight deck, screen configuration, and global settings; hide it when the user taps outside.
- Add global settings for Bluetooth flight-device connections, appearance (system/light/dark), language, and measurement system (metric/imperial).
- Add configurable map sources and optional overlays such as flight zones, flown track, and planned track for pages that include a map widget, limited to approved/licensed and available sources.
- Preserve mandatory simulated-flight labeling and keep development-only mock controls out of production settings.

## Capabilities

### New Capabilities
- `flight-screen-configuration`: Defines the application shell, primary navigation, configurable flight pages and widgets, global settings, automatic landing/thermaling page behavior, and map source/overlay configuration.

### Modified Capabilities
- None.

## Non-Goals

- Defining final thermaling detection thresholds or sensor algorithms beyond consuming the thermaling state signal from existing flight logic.
- Introducing cloud sync/sharing for page layouts in this change.
- Implementing or claiming production support for a Bluetooth device whose protocol/transport has not passed its independent validation and platform-support gates.
- Selecting the production map engine or approving new map/data providers; this change consumes the outcomes of the map benchmark and data-source governance changes.
- Adding page-layout profiles or making development-only mock-flight controls user-configurable in production.

## Impact

- Affected code: Flutter application shell/routing, flight page container, widget/layout configuration UI, global settings, native Bluetooth adapter entry points, map configuration/overlay plumbing, thermaling state integration, and existing live/simulated flight views.
- APIs/contracts: Introduces internal contracts for app routes, page definitions, widget descriptors, global preferences, device connection state, unit formatting, and thermaling auto-switch behavior.
- Cross-change dependencies: Bluetooth settings expose only platform/device support established by transport validation; map choices consume the selected offline engine and approved source catalogue; mock mode retains its production exclusion and visible simulation marker.
- Offline/safety: Navigation, essential widgets, saved settings, and installed map data MUST remain usable offline; UI work MUST NOT block core sensor/audio paths; thermaling changes affect only the flight deck and MUST NOT forcibly dismiss settings or configuration routes.
- Privacy: Page/settings data remains local; Bluetooth discovery identifiers and precise flight data MUST not be uploaded by this change.
- Licensing: Map choices MUST surface required attribution and exclude blocked, expired, or unapproved sources.
