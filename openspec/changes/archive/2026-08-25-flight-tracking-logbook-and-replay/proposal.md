## Why

Paragliding and hang gliding pilots need seamless, automatic flight tracking that captures complete flights from takeoff to landing without manual start/stop interactions. Pilots also require a local-first flight logbook to manage, search, analyze, and replay their flights across customizable flight instrument screens at variable speeds, export tracklogs in open standards (IGC format, JSON, CSV), and upload flights directly or automatically to XContest.org.

## What Changes

- **Automatic Flight Tracking & Hybrid Sensor Fusion**:
  - Implement real-time flight state machine (`GroundPreflight`, `Flying`, `Landed`, `Saved`).
  - Automatic takeoff detection via sustained ground speed (> 12 km/h) or vertical velocity (|vario| > 0.8 m/s for >= 4s), reinforced by terrain elevation (DEM / Height Above Ground delta > 15m) when available.
  - 15-second pre-takeoff circular buffer to preserve the launch trajectory in recorded tracklogs.
  - Automatic landing detection via sustained low ground speed (< 8 km/h) and settled vertical velocity for >= 20 seconds.
  - Configurable detection sensitivity thresholds in Flight Settings.
  - Continuous recording and persistent storage in standard FAI IGC format, JSON, and CSV.
- **Flights Screen & Logbook Management**:
  - Dedicated "Flights" view accessible from the top navigation bar menu.
  - Distinct sections/tabs for "My Flights" (recorded/flown flights) and "Planned Flights" (placeholder/routes for future flight planning).
  - Real-time search and filter capabilities for flights by title, pilot name, site, date, duration, and distance.
  - Flight card management actions: View Details, Rename, Delete, Share/Export (IGC format, JSON, CSV), and Replay.
  - Pre-bundled sample flight (`Krippenstein-Aussee`) loaded on first startup with full deletion support and a "Restore Sample Flight" action.
  - Manual flight import supporting IGC format and JSON files with destination category selector ("My Flights" vs "Planned Flights").
- **Interactive Real-Time Flight Replay**:
  - Launch flight replay from the logbook directly into the active flight and thermaling screens.
  - Feed real-time telemetry snapshots (altitude, vertical speed, ground speed, glide ratio, heading, coordinates, HAG) into all modular flight widgets.
  - Floating bottom Replay HUD with Play/Pause, timeline scrubber, elapsed/remaining time, exit button, and speed multiplier cycling: 1x -> 2x -> 3x -> 4x -> 5x -> 6x -> 7x -> 8x -> 1x.
  - Persistent HUD docking across screen transitions (custom layouts + thermaling assistant).
- **Post-Flight Summary & Robust XContest Integration**:
  - Automatic modal post-flight summary sheet displayed immediately upon landing detection (duration, max/min altitude, max climb/sink, total distance, average glide, and route preview).
  - One-tap manual upload to XContest.org from post-flight summary and flight detail card.
  - Offline upload queue with automatic background sync when internet connectivity is restored in landing areas with poor cell coverage.
  - General Settings configuration for XContest account credentials and "Auto-upload to XContest.org on landing" toggle.

## Capabilities

### New Capabilities
- `flight-tracking-and-logbook`: Sensor-based automatic takeoff/landing state machine with terrain DEM fusion, continuous flight recording, IGC format/JSON/CSV storage, logbook screen with search/filtering, manual flight upload, bundled sample flight with restore action, and post-flight summary sheet.
- `flight-replay-engine`: Deterministic real-time playback engine feeding recorded track telemetry into flight widgets and thermaling assistant with floating bottom HUD and 1x to 8x speed stepping.
- `xcontest-flight-submission`: Manual and automated upload of recorded flights to XContest.org with offline queue, auto-sync upon network recovery, and credential management.

### Modified Capabilities
- `xcontest-integration-readiness`: Gate real-network upload operations behind authenticated credentials, explicit user consent, offline queuing, and mock/offline fallback compliance.

## Impact

- **Mobile App UI**: New `FlightsScreen` widget, `ReplayControlOverlay` floating bottom HUD, `FlightSummarySheet` modal, updated `TopNavBarOverlay` and `UISettingsPanel`.
- **Services & Core**: New `FlightTrackingService`, `FlightStorageService`, `IGCParserService`, `FlightReplayService`, and `XContestUploadService`.
- **Platform & Assets**: Bundled `Krippenstein-Aussee` sample flight asset initialized into local document storage.
- **Security & Privacy**: Strict local storage of flight logs, secure credential storage for XContest authentication, explicit pilot confirmation for uploads.
- **GitHub Issue**: Authoritative OpenSpec issue tracked in this repository.
