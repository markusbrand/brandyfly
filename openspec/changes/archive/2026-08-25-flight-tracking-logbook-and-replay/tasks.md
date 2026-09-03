## 1. Core Flight Tracking & Hybrid Takeoff/Landing Detection

- [x] 1.1 Implement `FlightTrackingService` with 4-state state machine (`GroundPreflight`, `Flying`, `Landed`, `Saved`)
- [x] 1.2 Implement pre-takeoff circular buffer (15-second window) and hybrid takeoff detection heuristics (GPS speed + vario + DEM HAG reinforcement)
- [x] 1.3 Implement landing detection heuristic with settling window (20-second threshold) and automatic log finalization
- [x] 1.4 Add customizable threshold settings in `FlightSettings` (takeoff speed, vertical climb, landing settling time)
- [x] 1.5 Add unit tests for takeoff, false-positive rejection, and landing state transitions

## 2. Flight Storage & Multi-Format Serialization

- [x] 2.1 Implement `IGCParserService` to parse standard FAI IGC format files (headers, I-records, B-records) and generate valid IGC format files
- [x] 2.2 Implement JSON and CSV exporters for recorded flight tracks
- [x] 2.3 Implement `FlightStorageService` for local file persistence, flight metadata indexing, deletion, and renaming
- [x] 2.4 Add unit tests for IGC parsing, serialization, and round-trip fidelity

## 3. Bundled Sample Flight & Manual Import

- [x] 3.1 Bundle `Krippenstein-Aussee` sample flight into app assets and implement first-launch seeding into "My Flights"
- [x] 3.2 Implement "Restore Sample Flight" action in Flights Screen overflow menu
- [x] 3.3 Implement manual file import picker for IGC format and JSON files
- [x] 3.4 Add destination category selector ("My Flights" vs "Planned Flights") during manual import
- [x] 3.5 Add tests verifying sample flight seeding, restoration, and manual import flows

## 4. Flights Screen & Logbook Management UI

- [x] 4.1 Create `FlightsScreen` with "My Flights" and "Planned Flights" tabs, accessible via top navigation drawer
- [x] 4.2 Add real-time search bar and filter controls (by title, site, pilot, date, duration)
- [x] 4.3 Implement flight cards with metadata display and action menu (Details, Rename, Delete, Share/Export, Replay)
- [x] 4.4 Add widget tests for flight list rendering, search filtering, and flight deletion

## 5. Interactive Real-Time Flight Replay Engine

- [x] 5.1 Implement `FlightReplayService` that parses tracklogs and emits timed `FlightSnapshot` streams
- [x] 5.2 Integrate replay stream into `main.dart` and `LayoutStrategyContainer` widgets
- [x] 5.3 Create floating bottom `ReplayControlOverlay` HUD with Play/Pause, scrubber slider, timestamp, exit button, and speed cycling (1x -> 2x -> 3x -> 4x -> 5x -> 6x -> 7x -> 8x -> 1x)
- [x] 5.4 Ensure floating bottom HUD remains docked across screen swipes (custom screens + thermaling assistant)
- [x] 5.5 Add widget and integration tests for replay control transitions and speed multiplier stepping

## 6. Post-Flight Summary Sheet & Resilient XContest Integration

- [x] 6.1 Implement `FlightSummarySheet` modal bottom sheet triggered upon landing detection showing key stats, route mini-map, and actions
- [x] 6.2 Implement `XContestUploadService` with offline upload queue and automatic network recovery synchronization
- [x] 6.3 Add XContest account configuration and "Auto-upload on landing" toggle in General Settings
- [x] 6.4 Add manual "Retry Upload" action for queued/failed uploads in Flights Screen
- [x] 6.5 Add tests for post-flight summary triggering, offline queueing, and XContest upload status handling
