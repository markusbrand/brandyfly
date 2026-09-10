## Why

Currently, the GPS flight track on the base map renders with a single uniform color determined solely by the instantaneous climb rate. When a pilot transitions between thermals, glides, and sink lines, the entire historical path turns uniform green, yellow, or red. Paragliding pilots need a dynamic, continuously color-graded flight track that visualizes lift, neutral glides, and sink rates along their recent flight path to instantly recognize thermal cores, rising air streaks, and downdraft zones.

## What Changes

- Replace the uniform single-color `Polyline` in `MapWidget` with multi-segment, climb-rate colorized polylines.
- Implement smooth continuous gradient interpolation between configured color stops:
  - Strong Lift ($\ge +3.5\text{ m/s}$): Solid / Dark Emerald Green (`#15803D`)
  - Usable Lift ($+1.5\text{ m/s}$): Vibrant Green (`#22C55E`)
  - Weak Lift ($+0.5\text{ m/s}$): Soft / Pale Green (`#86EFAC`)
  - Neutral / Minimal Lift & Sink ($-0.5\text{ m/s}$ to $+0.5\text{ m/s}$): Neutral Slate Grey (`#94A3B8`)
  - Light Sink ($-0.5\text{ m/s}$ to $-1.5\text{ m/s}$): Soft / Pale Red (`#FCA5A5`)
  - Medium Sink ($-1.5\text{ m/s}$ to $-3.0\text{ m/s}$): Medium Red (`#EF4444`)
  - Severe Sink ($\le -3.0\text{ m/s}$): Deep Dark Red (`#991B1B`)
- Add configurable time windowing (default: **10 minutes**, options: 2, 5, 10, 15, 30, All) for the high-contrast colored flight trail.
- Add an optional muted, thin historical baseline for track segments older than the active time window.
- Expose track history window duration and lift/sink gradient parameters in `WidgetPlacementModel`, `UIConfig`, and `UISettingsPanel`.
- Pass detailed flight track telemetry (`FlightPoint` list with coordinates and vario) from `FlightTrackingService` and `FlightReplayService` to `MapWidget`.

## Capabilities

### Modified Capabilities
- `flight-tracking-logbook-and-replay`: Extend live map track visualization and flight replay rendering to support segmented continuous lift/sink color gradients and time-windowed historical track decay.
- `screen-widget-configuration`: Add `mapTrackHistoryMinutes`, `mapTrackShowOlderTail`, and threshold configuration options to `WidgetPlacementModel` and map settings UI.

## Non-Goals
- Replacing `ThermalMapWidget` (which remains dedicated to focused circling assistant calculations, core drift vectors, and thermal centroid estimation).
- 3D flight trajectory / ribbon terrain rendering.

## Impact
- **Flight Map Widget**: `apps/mobile/lib/widgets/flight/map_widget.dart`
- **UI Configuration**: `apps/mobile/lib/models/ui_config.dart`
- **UI Settings Panel**: `apps/mobile/lib/widgets/settings/ui_settings_panel.dart`
- **Layout Container**: `apps/mobile/lib/widgets/layout/layout_strategy_container.dart`
- **Telemetry Pipeline**: `apps/mobile/lib/services/flight_tracking_service.dart`, `apps/mobile/lib/services/flight_replay_service.dart`
- **Tests**: `apps/mobile/test/map_widget_integration_test.dart`, `apps/mobile/test/widgets_test.dart`, `apps/mobile/test/models/ui_config_test.dart`
