# Proposal: Rework Fullscreen Flight UI and Zero-Dead-Space Widgets

## Why

In paragliding flight computer applications, cockpit readability and situational awareness are paramount. Pilots operate with their mobile devices mounted on a flight deck or cockpit harness where screen real estate is at a premium and must be readable at arm's length under bright sunlight.

Currently, the BrandyFly flight screen suffers from excessive "dead space" and wasted screen area:
1. **Static Top Bars and Scaffolds**: The flight screen is hosted inside a traditional `Scaffold` with a permanent `AppBar` and debug/session cards, forcing the actual flight canvas (`LayoutStrategyContainer`) into a restricted nested box (`380-520px`).
2. **Persistent Navigation & Replay HUDs**: Top navigation and bottom replay controls occupy static vertical space instead of appearing as temporary, gesture-invoked overlays.
3. **Dead Space within Widgets**: Instrument widgets (`NumericTextWidget`, `VarioLiftSinkBar`, `WindDirectionWidget`, `AltitudeSparklineChart`) contain large outer/inner paddings, fixed-dimension sub-containers, and small fonts inside `FittedBox` wrappers, leaving significant unused empty space in each grid cell.
4. **Layout Grid Boundaries**: The layout strategy container uses static minimum cell heights and arbitrary padding rather than dynamically expanding to 100% of the display viewport.

## What Changes

1. **Edge-to-Edge Fullscreen Flight Screen**:
   - The active flight screen (live tracking, simulated/mock mode, or replay) utilizes 100% of the display viewport edge-to-edge.
   - The map layer and screen layout span the entire display height and width without static `AppBar`, scroll containers, or permanent padding cards.

2. **On-Demand Gesture-Driven Overlays**:
   - **Top Navigation Bar**: Hidden by default during flight. It slides down on demand via a swipe-down gesture from the top screen edge (or by tapping a subtle top-edge grab handle) and dismisses on swipe-up or backdrop tap.
   - **Playback / Recorder Navigation**: Replay controls are presented as a temporary bottom overlay that can be pulled up on demand (swipe up from bottom edge) or collapsed into a minimal indicator handle during flight replay.
   - **Flight Status & Debug Info**: Mock session controls and live status are integrated into floating, non-intrusive overlays / chips that never disrupt or shrink the flight instrument canvas.

3. **Zero-Dead-Space Responsive Widgets**:
   - **Numeric Instrument Widgets** (`NumericTextWidget`): Tightened paddings (2–4px), optimized layout hierarchy, maximizing digit typography size so numbers fill their container bounds with maximum legibility.
   - **Vario Lift/Sink Bar** (`VarioLiftSinkBar`): Dynamically scales to fill the widget frame height and width, removing fixed inner width constraints while preserving high-contrast climb/sink visual indicators.
   - **Wind Direction & Sparkline Chart Widgets** (`WindDirectionWidget`, `AltitudeSparklineChart`): Minimized header margins and maximized active indicator and graph canvas areas.
   - **Layout Strategy Containers** (`LayoutStrategyContainer`): Eliminates inter-cell dead space, providing seamless edge-to-edge widget placement and full-bleed map backgrounds.

## Capabilities

- Fullscreen edge-to-edge map and flight screen rendering taking advantage of 100% of the display area.
- Pull-in on-demand navigation overlays via swipe-down (top nav) and swipe-up (playback/recorder nav).
- High-density, high-legibility paragliding instrument widgets with zero wasted dead space.

## Non-Goals

- Modifying core FAI IGC logging, track recording algorithms, or telemetry math.
- Modifying backend service sync or cloud upload endpoints.

## Impact

- `apps/mobile/lib/main.dart`: Refactor live, mock, and replay shell views to be 100% fullscreen edge-to-edge without static AppBars or card wrappers.
- `apps/mobile/lib/widgets/navigation/top_nav_bar.dart`: Enhance swipe down gesture detection and smooth animated pull-down overlay presentation.
- `apps/mobile/lib/widgets/flight/replay_control_overlay.dart`: Rework into a collapsible, swipe-up bottom overlay with smooth collapse/expand and full-bleed backing.
- `apps/mobile/lib/widgets/layout/layout_strategy_container.dart`: Adapt grid scaling and widget frames to eliminate dead space and stretch dynamically across the full viewport.
- `apps/mobile/lib/widgets/flight/numeric_text_widget.dart`: Maximize typography scale, reduce internal padding, and eliminate dead space.
- `apps/mobile/lib/widgets/flight/vario_lift_sink_bar.dart`: Make bar and text scale responsively to full bounding box.
- `apps/mobile/lib/widgets/flight/wind_direction_widget.dart` & `altitude_sparkline_chart.dart`: Optimize canvas and text density.
- Unit and widget test suite in `apps/mobile/test/` updated and expanded.
