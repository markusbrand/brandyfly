## Why

Currently, widget and screen styling/configuration (such as map layers, widget styles, orientation, and layout strategy) are stored in a global monolithic configuration (`UIConfig`) and edited from a global settings panel. This prevents pilots from configuring widgets independently per screen (e.g. having a zoomed-in thermal radar on one screen and a north-up topo navigation map on another). Moving settings to their respective screen and widget models provides maximum layout flexibility, cleans up the global settings UI, and establishes a logical domain architecture for flight instrumentation.

## What Changes

- **Widget-Level Customization**: Introduce instance-specific configuration properties for widgets (style, map orientation, airspace/thermal overlays, numeric display units, custom labels, vario scale ranges, and altitude chart window) on `WidgetPlacementModel`.
- **Screen-Level Configuration**: Retain and expand `FlightScreenModel` to own its layout strategy (`LayoutStrategyStyle`) and screen auto-switching rules (e.g., auto-switch to thermaling screen on circling entry).
- **Edit Mode Widget Config Dialog**: Upgrade the edit-mode configuration modal from simple coordinate adjustment to full widget-specific tuning and style selection.
- **Global Settings Simplification**: Streamline the main Settings screen to focus solely on global app concerns: Flight Computer & Sensor thresholds, Audio Vario profiles, Screen management, Cloud/XContest sync, and Shell appearance.
- **Built-in Widget Defaults**: New widget placements automatically inherit default styling defined directly by the widget type.

### Non-Goals

- Changing or refactoring low-level flight sensor algorithms or GPS data acquisition pipelines.
- Introducing a web-based layout builder or cloud-synced custom themes.
- Rewriting underlying MapLibre / PMTiles vector rendering engines.

## Capabilities

### New Capabilities
- `screen-widget-configuration`: Defines requirements for screen-level layout strategies, widget-specific styling and layer configurations, in-place edit mode configuration, and simplified global settings.

### Modified Capabilities
<!-- None -->

## Impact

- **Affected Code**: `UIConfig`, `FlightScreenModel`, `WidgetPlacementModel`, `ScreenManagerService`, `LayoutStrategyContainer`, `_WidgetEditFrame`, `UISettingsPanel`, and flight widget implementations (`MapWidget`, `NumericTextWidget`, `VarioLiftSinkBar`, `WindDirectionWidget`, `AltitudeSparklineChart`).
- **Offline & Safety Impact**: All screen and widget configurations remain 100% local and offline-functional. Customizations do not block the UI or delay vario audio processing.
- **Privacy & Licensing**: MIT licensed; all configuration state stays local on the device.
- **GitHub Issue**: TBD
