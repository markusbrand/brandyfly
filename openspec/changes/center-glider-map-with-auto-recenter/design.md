## Context

In flight navigation, keeping the paraglider in constant visual reference is critical. Currently, `MapWidget` and `ThermalMapWidget` allow manual gestures but lack an auto-recenter mechanism and orientation-aware forward bias.

## Architecture Decisions

### 1. Viewport Anchoring & Camera Projection (`MapWidget`)

To support both **North-Up** (50%/50% center) and **Track-Up** (40% bottom / 60% top forward bias):
- When `orientation == MapOrientation.northUp`:
  - Camera center = `pilotPos`.
  - Glider marker is placed at `pilotPos` with `headingDeg` rotation.
- When `orientation == MapOrientation.trackUp`:
  - The visual glider arrow is fixed pointing vertically UP on screen.
  - Camera center is offset along the forward flight heading vector by `verticalBiasRatio * viewportHeightInMeters` so that the pilot's coordinate appears at 40% from bottom (0.6 * height from top), or by using Flutter's layout alignment `Alignment(0.0, 0.2)` combined with camera offset projection.
  - Map tile rotation is locked to `-headingDeg`.

### 2. Auto-Recenter Inactivity State Machine

Both `MapWidget` and `ThermalMapWidget` will incorporate an internal `Timer? _recenterTimer` instance:
```
  [State: Centered & Locked]
         │ (User Pan Gesture)
         ▼
  [State: Uncentered] ─── (Further Pan) ──► (Reset 6s Timer)
         │
         ├─── (6s Inactivity Timeout) ──► [Recenter & Lock]
         └─── (Tap Recenter Button)    ──► [Recenter & Lock]
```
- Duration: 6 seconds (`Duration(seconds: 6)`).
- On widget disposal, `_recenterTimer?.cancel()` ensures no timer leaks or setState on unmounted widgets.

### 3. Thermal Radar (`ThermalMapWidget`) Positioning

In `ThermalMapWidget`, thermals and drift are circular/helical around the pilot. Glider position is rendered at exact `(0, 0)` in translated canvas space `(size.width / 2, size.height / 2)` with no vertical bias. Pan gesture accumulates into `_panOffset`, which is cleared back to `Offset.zero` upon auto-recenter timeout or recenter button click.

## Trade-offs & Alternatives Considered

- **Complete Gesture Lock (No Panning)**: Too restrictive; pilots often need a quick 2-second glance at an upcoming airspace ceiling or distant mountain ridge.
- **33% Bottom Bias**: Too close to the bottom edge on tall phone screens, cutting off rear glide track visibility. The chosen 40% bottom (60% ahead) offers optimal forward look-ahead while retaining adequate rear context.
