## Why

When paragliding pilots enter a thermal and begin circling, rapid situational awareness of the thermal's core and surrounding sink is critical for centering and climbing efficiently. 

Leading paragliding flight instruments (such as XCtrack, Burnair Go, Navigator, and Flyskyhy) provide dedicated thermal assistant screens featuring visual breadcrumb tracks composed of colored lift and sink circles. In BrandyFly, pilots need a dedicated thermal map visualization where uplift is shown in green and sink in red, with transparency and intensity scaling according to the strength of climb/sink.

This visualization must be fully integrated into BrandyFly's modular grid widget system: adjustable in size and position, covering full screen by default on the thermaling screen, and positioned above the background terrain map while staying underneath all foreground instrument widgets.

## What Changes

- **New Widget Type (`WidgetType.thermalMap`)**: Introduce a dedicated Thermal Map widget to the widget catalog and `WidgetPlacementModel`.
- **Lift/Sink Circles Visualization**: Render circling track breadcrumbs as green circles for uplift (> 0 m/s) and red circles for sink (< 0 m/s). Opacity (transparency) dynamically scales with climb/sink magnitude (high opacity for strong lift/sink, translucent for light lift/sink).
- **Z-Index & Layering Strategy**: Update `LayoutStrategyContainer` widget sorting so that:
  - Base terrain map is rendered on the lowest layer (`layer 0`).
  - Thermal map widget is rendered in the middle layer (`layer 1`), directly over the map.
  - Foreground instruments (altitude, speed, vario bar, wind, glide, etc.) are rendered on top (`layer 2+`).
- **Default Thermaling Screen Layout**: Configure the default `thermaling` screen to include the full-screen `thermalMap` widget by default (w: 4, h: 4) behind the primary instrument overlays.
- **Customizable Widget Geometry**: The thermal map can be resized, repositioned, added, or removed on any screen just like any other BrandyFly widget.
- **Style Presets Inspired by Reference Apps**: Support distinct visual style presets (XCtrack bubble trail, Burnair core assist, Navigator heat ribbon, and Flyskyhy clean radial).

## Capabilities

### New Capabilities
- `thermaling-screen-lift-sink-map`: Dedicated thermal assistant map widget with green uplift and red sink circles, dynamic alpha transparency, customizable widget bounds, and layer ordering above the base map and below instrument overlays.

### Modified Capabilities
<!-- None -->

## Impact

- **Mobile App (`apps/mobile`)**:
  - `lib/models/ui_config.dart`: New `WidgetType.thermalMap`, `ThermalMapStyle` enum, placement model extensions, and updated default thermaling screen.
  - `lib/widgets/layout/layout_strategy_container.dart`: Updated widget layer ordering (`_getOrderedWidgets`), widget renderer, and widget settings inspector.
  - `lib/widgets/layout/widget_picker_sheet.dart`: Thermal Map widget option in picker sheet.
  - `lib/widgets/flight/thermal_map_widget.dart` (new): Custom painter and interactive canvas for rendering lift/sink bubbles, circling track, glider heading icon, and estimated thermal core.
- **Tests**:
  - `test/models/ui_config_test.dart`
  - `test/widgets_test.dart`
  - `test/screen_manager_test.dart`
