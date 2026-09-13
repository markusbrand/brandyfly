## Why

During paragliding flights, pilots rely on continuous, glanceable situational awareness. The glider position marker must remain reliably centered on the screen so the pilot always knows their position relative to surrounding terrain, airspace boundaries, and thermal hotspots.

Currently, if the map is panned or if coordinates update, map centering can become detached, leaving the glider icon positioned inconsistently or off-screen. Furthermore:
1. In **Track-Up** flight orientation, true 50/50 center wastes visible screen real estate behind the glider; a forward-looking bias (40% from bottom / 60% ahead) allows pilots to see significantly more upcoming airspace and obstacles.
2. In **North-Up** and **Thermal Radar** mode, a true 50/50 center is necessary to maintain an unobstructed 360° overview of circling thermals and wind drift.
3. When pilots temporarily pan the map to inspect nearby features, having the map automatically return to center after a short inactivity timeout ensures hands-free safety without requiring glove taps on small HUD buttons while flying.

## What Changes

- **Continuous Glider Centering**: The map automatically keeps the paraglider icon centered at the target viewport anchor as telemetry updates arrive during live flight and IGC replay.
- **Orientation-Aware Viewport Anchor**:
  - **Track-Up Mode**: Glider arrow is fixed pointing UP and anchored at 50% horizontal, 40% from bottom (60% from top), providing expanded forward visibility along the flight track.
  - **North-Up Mode**: Glider arrow is anchored at exact 50% X / 50% Y (true center) and rotates according to GPS heading.
  - **Thermal Map Mode**: Thermal radar canvas maintains a strict 50% X / 50% Y true center for circling thermals.
- **Temporary Panning & Auto-Recenter Inactivity Timer**:
  - When the pilot pans or drags the map (`MapWidget` or `ThermalMapWidget`), the view temporarily uncenters to permit manual inspection.
  - An inactivity timer (6 seconds) resets on every pan gesture. When user interaction ceases for 6 seconds, the viewport smoothly re-centers on the pilot and restores center-lock.
  - The HUD "Recenter" button displays active state when uncentered and immediately re-engages center-lock on tap.

## Capabilities

- Real-time continuous pilot viewport tracking across all telemetry coordinate changes.
- Forward-looking 40% bottom / 60% top bias in Track-Up map orientation.
- Consistent 6-second auto-recenter timeout across both `MapWidget` (OSM/Topo) and `ThermalMapWidget` (Thermal radar).
- Immediate manual recenter capability via one-touch HUD action button.

## Non-Goals

- Changing base tile providers, caching engines, or vector rendering pipelines.
- Adding route planning or waypoint waypoint-radius editor tools (handled under future XC navigation specs).
- Changing widget layout grid system or sizing.

## Impact

- Improves flight safety and hands-free usability under turbulent conditions where screen interaction is limited.
- Modifies `apps/mobile/lib/widgets/flight/map_widget.dart` and `apps/mobile/lib/widgets/flight/thermal_map_widget.dart`.
- Enhances widget tests in `apps/mobile/test/map_widget_integration_test.dart` and `apps/mobile/test/widgets_test.dart`.
