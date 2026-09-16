## Context

See `proposal.md` for motivation. In `apps/mobile/lib/widgets/flight/map_widget.dart`, `_FlightOverlayPainter` renders flight-specific overlays on top of the MapLibre GL map. The airspace polygon (`_paintAirspace`) and thermal lift markers (`_paintThermals`) are currently derived dynamically by adding latitude/longitude offsets to `pilotPosition`:

```dart
_toScreen(LatLng(pilotPosition.latitude + 0.025, pilotPosition.longitude - 0.035), size)
```

Because `pilotPosition` updates at 1 Hz during simulation or live flight, these overlays move in lockstep with the glider rather than behaving as fixed Earth objects.

## Goals / Non-Goals

**Goals:**
- Anchor mock airspace limitation zones to fixed geographic coordinates around the Dachstein/Krippenstein flight site (`47.525°N, 13.685°E`).
- Anchor mock thermal lift hotspots (`+2.8`, `+3.4`, `+1.9`) to fixed geographic coordinates on the terrain.
- Ensure the static coordinates project correctly via `_toScreen()` under map zooming, panning, and track-up/north-up rotation.

**Non-Goals:**
- Full dynamic OpenAir file download or 3D vertical proximity calculation (covered by change `openair-airspace-parser-3d-proximity`).
- Modifying pilot position marker or vario breadcrumb track rendering.

## Decisions

### 1. Define Static Geographic Constants
- **Choice**: Define fixed `List<LatLng>` for the mock airspace boundary and `List<(LatLng, String)>` for the mock thermal lift hotspots in `_FlightOverlayPainter`:
  - Reference center: Dachstein / Krippenstein (`47.525°N, 13.685°E`).
  - Airspace polygon: Coordinates bounding a realistic simulated CTR/restricted zone in the valley/mountain pass (e.g. `[LatLng(47.550, 13.650), LatLng(47.560, 13.710), LatLng(47.535, 13.725), LatLng(47.510, 13.675)]`).
  - Thermal hotspots: Placed on realistic sun-facing mountain slopes near Krippenstein (e.g. `(LatLng(47.533, 13.697), '+2.8')`, `(LatLng(47.519, 13.703), '+3.4')`, `(LatLng(47.513, 13.676), '+1.9')`).
- **Alternatives Considered**: Keeping them as offsets relative to an initial takeoff point was considered, but static constants are simpler, deterministic, and prevent any drift during long flight replays.

### 2. Leverage Existing `_toScreen()` Mercator / Controller Projection
- `_toScreen(LatLng point, Size size)` projects any geographic coordinate to widget screen coordinates based on `cameraCenter`, `zoom`, and `headingDeg`.
- By passing fixed geographic `LatLng` values, the airspace and thermals remain stationary on Earth while the camera and pilot icon move naturally.

## Risks / Trade-offs

- **Viewport culling / out-of-range when flying far away**: If the pilot flies hundreds of kilometers away from the Alps-East region, the mock airspace will be out of viewport.
  - *Mitigation*: This is authentic paragliding flight computer behavior. Airspaces and thermals only exist at their real physical locations on Earth.
