# Design

## Context

See `proposal.md` for motivation and scope.

In the current mobile architecture (`apps/mobile`):
- Both `FlightTrackingService` and `TelemetryRepository` attach listeners to `ITelemetrySource.telemetryStream`.
- `TelemetryRepository` also registers `_trackingService?.addListener(_onTrackingChanged)`.
- During `FlightState.flying`, `FlightTrackingService._handleFlyingPoint()` calls `notifyListeners()` on every incoming `FlightPoint`. This causes `TelemetryRepository` to emit two `CockpitTelemetry` snapshots for every sensor tick: once in `onSnapshot()` and a second time immediately via `_onTrackingChanged()`.
- In `FlightWidgetContent` (`widget_slot.dart`), `WidgetType.airspaceSideCut` is the only instrument using a raw `ValueListenableBuilder<CockpitTelemetry>` instead of `ValueSelector`, and it calls `airspaceService.getForwardAirspaces(...)` (51 steps × $N$ polygons) synchronously inside `build()`.
- `ReplayControlOverlay` and `TopNavBarOverlay` wrap their containers in `BackdropFilter(filter: ImageFilter.blur(...))` over the live MapLibre platform view.
- `TelemetryRepository.onSnapshot` sets `glide: _idle.glide` (`8.4`) instead of computing real rolling glide performance.

## Goals / Non-Goals

**Goals:**
- Guarantee 1 `CockpitTelemetry` emission per incoming `TelemetrySnapshot` tick during both preflight and active flight.
- Reduce `FlightTrackingService` `ChangeNotifier` notifications during `FlightState.flying` to whole-second elapsed duration transitions and state/settings changes.
- Scope `AirspaceSideCutWidget` rebuilds via `ValueSelector` + `RepaintBoundary` and cache `AirspaceService.getForwardAirspaces` spatial ray-casting across minor telemetry ticks.
- Eliminate `BackdropFilter` GPU blur passes from `ReplayControlOverlay` and `TopNavBarOverlay`.
- Provide a deterministic, zero-allocation rolling `GlideAverager` (15s window) in `TelemetryRepository`.

**Non-Goals:**
- Moving airspace ray-casting to a background Isolate or FFI call (caching with spatial/heading thresholds keeps Dart ray-casting at $\le 0.5\text{ Hz}$ on average, costing $< 0.2\text{ ms}$ when triggered).
- Changing `CockpitTelemetry` field types or breaking existing widget layout serialization.

## Decisions

### 1. Decoupling `TelemetryRepository` from Per-Point `FlightTrackingService` Notifications

- **Decision**:
  1. In `TelemetryRepository`, subscribe to `_trackingService?.stateStream` (or track `_lastKnownFlightState` / `_lastKnownTakeoffPoint` inside `_onTrackingChanged`) so `_onTrackingChanged` only re-emits when `state` or `takeoffPoint` actually transitions (e.g., manual recording start/stop or reset when no sensor snapshot is simultaneously arriving, and suppress redundant emission when `onSnapshot` already incorporated the state). Even simpler and cleaner:
     - In `FlightTrackingService._handleFlyingPoint(point)`, only call `notifyListeners()` when the whole-second elapsed duration (`point.timestamp.difference(_activeFlightPoints.first.timestamp).inSeconds`) changes compared to the previous point (so `RecordingStatusOverlay`'s `REC mm:ss` badge still updates at 1 Hz instead of 50 Hz).
     - In `TelemetryRepository._onTrackingChanged()`, check whether `_trackingService?.state` and `_trackingService?.takeoffPoint` changed since the last emission; if neither changed, return immediately without calling `_emitLiveOrIdle()`.
- **Alternatives Considered**:
  - *Removing `_trackingService.addListener` from `TelemetryRepository` completely*: Rejected because `startManualRecording()` or `reset()` can be tapped by the user while telemetry is idle or between ticks, and `TelemetryRepository` must immediately reflect the new `takeoffPoint` (or cleared `takeoffPoint`). Filtering `_onTrackingChanged()` on `(state, takeoffPoint)` identity/equality preserves instant manual transitions while eliminating all redundant per-tick emissions during flight.
- **Latency & Battery Trade-off**: Cuts `TelemetryRepository` work and downstream `ValueSelector` evaluations in half (50% reduction) during active flight, saving CPU cycles and battery on 10–50 Hz sensor feeds.

### 2. `AirspaceSideCutWidget` `ValueSelector`, `RepaintBoundary`, and Spatial Query Cache

- **Decision**:
  1. In `FlightWidgetContent` (`widget_slot.dart`), replace `ValueListenableBuilder<CockpitTelemetry>` for `WidgetType.airspaceSideCut` with `ValueSelector<CockpitTelemetry, (int, int, int, int, int, int, int)>` selecting:
     - quantized latitude (`((t.latitude ?? 47.53) * 1000).round()`, ~110 m grid or `* 4000` ~27 m grid)
     - quantized longitude (`((t.longitude ?? 13.68) * 4000).round()`)
     - rounded altitude (`t.altitude.round()`)
     - quantized groundspeed (`(t.speed / 3.6 * 10).round()`)
     - rounded heading (`t.effectiveHeading.round()`)
     - quantized glide ratio (`(t.glide.clamp(1.0, 30.0) * 10).round()`)
     - rounded HAG (`(t.hag ?? 300.0).round()`)
  2. Wrap `AirspaceSideCutWidget` (or its `CustomPaint`) in a `RepaintBoundary` and reuse `Paint` and `TextPainter` fields inside `AirspaceSideCutPainter` to honor the garbage-free `CustomPainter` requirement.
  3. In `AirspaceService.getForwardAirspaces(...)`, cache the last query parameters (`_cachedForwardLat`, `_cachedForwardLon`, `_cachedForwardAlt`, `_cachedForwardHeading`, `_cachedForwardLookahead`, `_cachedForwardGlide`, `_airspaceRevision`) and result (`_cachedForwardBlocks`). Return `_cachedForwardBlocks` when:
     - Airspace store revision matches
     - Horizontal shift $< 25\text{ m}$ (fast equirectangular check)
     - Heading delta $< 2.0^\circ$ (shortest angular distance)
     - Altitude delta $< 10.0\text{ m}$
     - Glide ratio delta $< 0.5$
     - Lookahead distance matches
- **Alternatives Considered**:
  - *Time-based throttling (e.g. `DateTime.now()`)*: Rejected because wall-clock throttling is non-deterministic in widget tests and flight replay at 10x speed. State-delta caching (position, heading, altitude, glide, revision) is 100% deterministic in both live flight and fast-forward replay.

### 3. Replacing `BackdropFilter` Blur with High-Contrast Bezel Surfaces

- **Decision**:
  - Remove `BackdropFilter(filter: ImageFilter.blur(...))` from `ReplayControlOverlay` and `TopNavBarOverlay._buildTranslucentDrawer`.
  - Use high-alpha dark cockpit surfaces (`CockpitTokens.nightPanel.withAlpha(235)` / ` Colors.blueGrey.shade900.withAlpha(240)`) with crisp borders and box shadows.
- **Alternatives Considered**:
  - *Keeping blur behind a settings flag*: Rejected because Gaussian blur over a platform view (`AndroidView` / `UiKitView` for MapLibre) forces Flutter's raster thread to perform offscreen saveLayer + texture readbacks on every frame while the overlay is visible, which is always active during replay (`ReplayControlOverlay`). High-alpha dark surfaces match the rest of `CockpitTokens` (`FloatingPill`, `CornerMenu`, `RecordingStatusOverlay`) which already avoid `BackdropFilter`.

### 4. Rolling `GlideAverager` for Live & Replay Telemetry

- **Decision**:
  - Create `GlideAverager` in `apps/mobile/lib/domain/thermal_assistant/glide_averager.dart` modeled after `ClimbAverager`:
    - Stores `(timestampMs, speedKmh, climbRateMs)` samples in a `Queue` over a configurable rolling window (default `Duration(seconds: 15)`, retention `35000 ms`, clearing on gaps $> 5000\text{ ms}$).
    - Computes mean horizontal speed in m/s ($\bar{v}_{h} = \overline{\text{speedKmh}} / 3.6$) and mean vertical speed in m/s ($\bar{v}_{z} = \overline{\text{climbRateMs}}$) over the window.
    - When $\bar{v}_{z} < -0.05\text{ m/s}$ (sinking/gliding) and $\overline{\text{speedKmh}} \ge 5.0\text{ km/h}$, computes instantaneous windowed $L/D = (-\bar{v}_{h} / \bar{v}_{z}).clamp(0.5, 50.0)$ and stores it as `_lastValidGlide`.
    - When climbing ($\bar{v}_{z} \ge -0.05\text{ m/s}$) or stationary ($\overline{\text{speedKmh}} < 5.0\text{ km/h}$), returns `_lastValidGlide ?? fallbackGlide` so numeric and side-cut consumers receive a stable, finite positive number without divide-by-zero or wild spikes.
  - Wire `GlideAverager` into `TelemetryRepository.onSnapshot` (using `fallbackGlide: _idle.glide`) and reset it in `detachSource()`.
- **Alternatives Considered**:
  - *Instantaneous single-tick `speed / -vario`*: Rejected because barometric vario fluctuates at 10–50 Hz; as `vario` approaches `0.0`, instantaneous L/D spikes wildly between `8.0` and `500.0`, causing constant UI rebuilds and unreadable instrument jitter. A 15-second rolling ratio matches standard paragliding vario computers (XCTrack / SkyDrop / Flymaster).

## Risks / Trade-offs

- **[Risk] Existing tests expecting `RecordingStatusOverlay` or `TelemetryRepository` listener counts** → Mitigation: `FlightTrackingService` still notifies immediately on state transitions (`startManualRecording`, takeoff trigger, landing trigger, `reset`, `updateSettings`) AND once per whole-second change while flying, so `RecordingStatusOverlay` tests (which advance by 65 seconds) continue to receive notifications and pass unchanged.
- **[Risk] Existing tests asserting `glide` equals `_idle.glide` on the first climbing snapshot** → Mitigation: When a snapshot is climbing (`vario >= -0.05`) and no prior descending glide sample exists, `GlideAverager` returns `fallbackGlide` (`_idle.glide`), preserving backward compatibility for climbing/initial snapshots while producing real L/D during descending glides.
