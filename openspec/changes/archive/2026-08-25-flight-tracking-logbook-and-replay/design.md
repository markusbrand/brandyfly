## Context

BrandyFly is a local-first paragliding vario app running on Flutter with modular customizable flight instrument widgets and native sensor bridges. Pilots fly in remote alpine areas without cellular connectivity, so automatic flight tracking, local logbook storage, and replay must operate entirely offline and with low latency, while supporting standardized open exchange formats (IGC format, JSON, CSV) and resilient post-flight XContest integration with offline queuing.

## Goals / Non-Goals

**Goals:**
- Provide reliable, hands-free takeoff and landing detection using barometric, GPS, and terrain DEM sensor fusion.
- Guarantee zero data loss during flights by streaming trackpoints directly to local disk.
- Store flights in valid FAI IGC format compliant with XContest and standard flight analysis tools.
- Implement an intuitive Flights Logbook screen with search, filtering, management, manual import, and sample restoration.
- Provide deterministic, real-time flight replay with a persistent floating bottom HUD and 1x to 8x speed stepping driving the modular widget suite.
- Provide modal post-flight summary sheet and resilient XContest upload with offline queue and auto-sync.

**Non-Goals:**
- Full turnpoint route planning editor in this phase (Planned Flights serves as catalog / placeholder for future planning phase).
- Live cloud tracking / live telemetry streaming (separate future capability).
- Direct BLE vario device driver implementation (uses existing sensor interface).

## Decisions

### 1. Hybrid Sensor & Terrain Fusion for Takeoff / Landing Detection
- Use a 4-state state machine: `GroundPreflight` -> `Flying` -> `Landed` -> `Saved`.
- **Takeoff Trigger**: Sustained GPS ground speed >= 12 km/h (or vertical climb/sink |vario| >= 0.8 m/s) for 4 consecutive seconds, reinforced by Height Above Ground (HAG) > 15m when terrain DEM data is active. Thresholds are user-configurable in Flight Settings.
- **Pre-Takeoff Circular Buffer**: Maintain a ring buffer of 15 seconds (15-30 samples) in memory while in `GroundPreflight` state. When takeoff is confirmed, dump the buffer into the start of the track file to capture the full launch run.
- **Landing Trigger**: Ground speed <= 8 km/h and |vario| <= 0.4 m/s for >= 20 seconds.
- *Alternatives considered*: Fixed velocity thresholds only (rejected because hybrid DEM elevation validation significantly reduces false launch triggers during ground handling).

### 2. Multi-Format Storage Engine (IGC / JSON / CSV)
- The primary archival format is standard FAI IGC format (ASCII B-records with timestamp, lat, lon, pressure altitude, GNSS altitude, vario, and speed).
- Metadata and point indices are indexed in local structured JSON for fast query and list rendering without re-parsing multi-megabyte track files on logbook load.
- CSV export is synthesized on demand or cached alongside IGC format files.
- *Alternatives considered*: SQLite database for all raw points (rejected because IGC format files are the universal exchange format; saving raw track files directly on disk ensures direct file sharing without export overhead).

### 3. Floating Bottom Replay HUD & Widget Injection
- `FlightReplayService` loads an IGC or JSON track, parses the points into ordered `FlightSnapshot` instances, and emits them over a broadcast stream.
- Replay stream replaces live telemetry when active, feeding the exact same `FlightSnapshot` models to `LayoutStrategyContainer`, numeric widgets, vario bar, altitude chart, and map overlay.
- Replay HUD is rendered as a floating translucent bottom bar containing Play/Pause, timeline scrubber slider, timestamp/elapsed time, speed cycling button (1x -> 2x -> 3x -> 4x -> 5x -> 6x -> 7x -> 8x -> 1x), and Exit Replay button.
- The HUD persists across horizontal swipe navigation between custom layouts and the thermaling assistant.
- *Alternatives considered*: Top bar controls or dedicated separate replay view (rejected because pilots want to experience and evaluate their real instrument layouts and thermaling assistant smoothly during replay).

### 4. Bundled Sample Flight (`Krippenstein-Aussee`) & Restoration
- Copy the sample flight into app assets (`assets/sample_flights/krippenstein_aussee_sample` or equivalent asset key).
- On first app launch, `FlightStorageService` copies the asset into local flight documents and indexes it in "My Flights".
- User can rename, replay, share, or delete the sample flight like any other recorded flight.
- If deleted, user can re-seed the sample flight anytime via "Restore Sample Flight" in the Flights Screen overflow menu.

### 5. Post-Flight Summary Sheet & Offline XContest Sync
- Modal bottom sheet automatically triggers on confirmed landing, showing flight duration, max altitude, max vario, total distance, average glide, and a mini-map route preview.
- Provides direct "Upload to XContest" and "View in Logbook" buttons.
- If offline when landing occurs, flights marked for auto-upload are placed in an "Upload Queued" state and automatically uploaded once network connectivity is re-established.
- Conforms to `openspec/specs/xcontest-integration-readiness/spec.md` with secure credential storage and clear error feedback.

## Risks / Trade-offs

- [False takeoff detection on bumpy ground or driving to launch] → Mitigation: Require sustained speed + altitude change for >= 4s and allow pilot to discard invalid track logs.
- [Premature landing detection during slow ridge soaring in strong headwind] → Mitigation: Require both zero vertical speed AND low groundspeed for 20+ seconds; allow resuming recording if speed increases again within 60 seconds.
- [High memory usage during long 8-hour flights] → Mitigation: Stream track points directly to disk file buffer incrementally rather than holding full flight array in RAM.
- [Replay timing jitter at 8x speed] → Mitigation: Adjust frame interval dynamically and batch intermediate points if rendering fps falls below threshold.
- [Landing zones without cell coverage] → Mitigation: Implement background connectivity observer to drain the offline upload queue when connectivity returns.

## Migration Plan

1. Create `FlightTrackingService`, `IGCParserService`, and `FlightStorageService`.
2. Add bundled asset `Krippenstein-Aussee` and first-run initialization logic with restore capability.
3. Build `FlightsScreen` UI with "My Flights", "Planned Flights", search, and action menus.
4. Implement `FlightReplayService` and floating bottom `ReplayControlOverlay` widget.
5. Implement `FlightSummarySheet` and `XContestUploadService` with offline queue manager.
6. Add unit and widget tests for tracking heuristics, IGC parser, logbook management, replay stream, and offline sync.
