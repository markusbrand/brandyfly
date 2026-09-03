## Why

BrandyFly lacks the foundational UI architecture to be a usable flight instrument. To support flight, pilots need an application that restores their last state, allows them to freely configure multiple screens (including a map, widgets, and thermal-specific modes), and integrates easily with external sensors. This establishes the MVP UI architecture required for first flights.

## What Changes

- Implement a multi-screen framework where screens can be freely added, removed, and configured by the user.
- Add an automatic "thermaling screen" transition triggered by circling in lift, reverting automatically when flying straight.
- Add a top-down navigation bar (swipe-to-reveal) containing access to Settings and "Edit Mode" for the current page.
- Create a Settings screen accessible from the navigation bar (configuring Bluetooth devices, XContest accounts, UI preferences like nav opacity, license/version info) that returns to the previous screen when dismissed.
- Implement an Edit Mode allowing users to resize, position, reorder (z-index), color (dark/light), and set transparency for any widget.
- Build a base Map widget supporting multiple sources (OSM, thermal maps, restricted airspace, XContest flight tracks).
- Build initial flight widgets: groundspeed, altitude, wind direction, wind speed, height above ground, glide ratio, flight height line chart, and a visual lift/sink rate bar.
- Provide a robust localization system (English, German) and dark/light mode switching.
- Establish a scalable architecture using best practices (Flutter, Riverpod/BLoC depending on standard) to easily add new widgets and maps later.
- Provide sensor integration using external Bluetooth variometers (like SkyDrop) primarily, falling back to internal phone/tablet sensors.

Non-goals:
- Full implementation of all map sources (focusing on the framework and OSM first, with stubs for others if needed).
- Complex sensor fusion (basic fallback from Bluetooth to internal is sufficient).
- Flight recording and upload to XContest (only account configuration for now).

## Capabilities

### New Capabilities
- `mvp-ui-architecture`: Defines the multi-screen, widget configuration, and top-down navigation framework.
- `flight-widgets`: Defines the initial set of widgets (map, altitude, groundspeed, wind, glide, vario, chart) and their configurable properties.
- `sensor-management`: Defines the priority-based sensor input system (Bluetooth vario -> internal sensors).
- `app-settings`: Defines the settings page requirements and localization/theming support.

### Modified Capabilities
None.

## Impact

This introduces the core Flutter UI architecture in `apps/mobile`. It will integrate with the native plugins for Bluetooth and internal sensors, and define how state is managed across the application. It heavily influences future UI development. Privacy must be considered if showing tracks, but for now this is mostly UI layout and local state. Safety-critical UI must remain responsive.
