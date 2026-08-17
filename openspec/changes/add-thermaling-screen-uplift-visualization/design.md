## Context

See proposal.md - Why for motivation. Currently, BrandyFly's mobile UI (Flutter/Dart in `apps/mobile/`) has a single flight screen with configurable widgets and maps. The flight core (`crates/flight_core/`, Rust) processes GPS and telemetry data and exports state via well-defined contracts to the UI layer. No thermaling detection logic exists, and the app has no mechanism to auto-switch screens based on flight state or to render geographic overlays (circle markers) in real time.

This design introduces thermaling detection as a new component in the flight core, extends the flight-state contracts to include thermaling episode and circle marker data, and adds a separate thermaling screen to the Flutter UI with independent configuration storage.

## Goals / Non-Goals

**Goals:**
- Detect thermaling patterns in the flight core using circling-pattern analysis and vertical speed data
- Generate circle markers (position, radius, color) for uplift and sink zones
- Provide a UI layer capable of rendering these markers on a map and auto-switching to a dedicated thermaling screen
- Make the thermaling screen independently configurable (map source, widget layout) without coupling to main screen settings
- Ensure all thermaling detection and rendering work offline

**Non-Goals:**
- Optimization for extreme edge cases (e.g., helicopter spirals, square patterns)
- Integration with external thermaling databases or weather services
- Real-time multiplayer thermaling sharing or cloud sync
- Predictive thermaling recommendation (see proposal - Non-Goals)

## Decisions

### Decision 1: Implement Thermaling Detection in Rust Flight Core

**Rationale:**
- Hot sensor processing and flight-critical logic are already in the flight core (`crates/flight_core/`)
- Keeps thermaling detection independent from UI thread to maintain app responsiveness
- Reuses existing GPS, altitude, and time data already flowing through the core
- Detection algorithms (circle detection, vertical rate aggregation) benefit from Rust's performance

**Alternatives Considered:**
1. Implement in Flutter/Dart UI layer → Risk: UI thread blocking if circling detection is expensive; harder to test offline
2. Implement in the Go backend → Issue: Backend is optional; feature must work without it

**Selected:** Rust flight core (Thermaling detection module)

---

### Decision 2: Thermaling Episode State as Discrete Messages to UI

**Rationale:**
- Keep the UI as a consumer of state changes, not a stateful processor
- Each thermaling episode and marker update becomes a clear event/notification
- Simplifies UI component lifecycle and re-rendering logic
- Aligns with existing event-driven patterns in Flutter (Riverpod, Provider, etc.)

**Alternatives Considered:**
1. Continuous polling of flight core state for thermaling → Risk: excessive UI queries, battery overhead
2. Bidirectional RPC calls → Complexity: violates unidirectional data flow

**Selected:** Event-driven state updates (flight core → UI via well-defined message types)

---

### Decision 3: Separate Configuration Storage for Thermaling Screen

**Rationale:**
- Pilots may want different map (e.g., satellite for thermaling, topographic for main flight) and widget layouts for different flight phases
- Avoids coupling, allowing independent iteration on each screen's UX
- LocalStorage or SharedPreferences in Flutter suffices (no backend needed)

**Alternatives Considered:**
1. Use a single shared config with screen-qualified keys → Issue: Adds complexity, couples the screens
2. Store in flight core and sync via contracts → Overhead: flight core is not a config manager

**Selected:** Separate configuration per screen, stored in Flutter local storage

---

### Decision 4: Circle Markers as Ephemeral (Session-Scoped) Data

**Rationale:**
- Thermaling circles are transient UI artifacts tied to the current flight
- Persisting them across app restarts adds database complexity without clear pilot value
- Simplifies data lifecycle: clear on new flight, deleted on app restart
- Aligns with the app's existing flight-session model

**Alternatives Considered:**
1. Persist circles to a local flight log database → Complexity: requires schema, migration, indexing; scope creep
2. Upload to backend for post-flight review → Out of scope (proposal omits this)

**Selected:** Session-scoped (memory/cache), cleared on new flight

---

### Decision 5: Automatic Screen Switching Triggered by Thermaling State

**Rationale:**
- Reduces pilot workload during flight; autopilot for screen selection
- Grace period (configurable, default 10s) prevents jitter on circle edges
- Pilots retain manual override (button/gesture to switch back to main)

**Alternatives Considered:**
1. Manual tap to enter thermaling screen → Adds workload at the moment pilots need focus
2. Persistent split-screen → Complex layout, cluttered UI on small devices

**Selected:** Auto-switch with manual override

---

### Decision 6: Configurable Thermaling Thresholds (Min Duration, Min Climb/Sink)

**Rationale:**
- Different flying styles (tight thermals vs. wide circles) and aircraft (slow vs. fast) need different detection tuning
- Pilots can optimize for their setup without code changes
- Default values (5s duration, 5m altitude change, 0.5kt vertical speed) are conservative starting points

**Alternatives Considered:**
1. Fixed detection thresholds → Risk: false positives in gusty conditions or tight circles
2. Automatic tuning → Scope creep; open research problem

**Selected:** Configurable thresholds with sensible defaults

---

### Decision 7: Circle Radius Scaled by Vertical Speed Magnitude

**Rationale:**
- Intuitive visual encoding: bigger circle = stronger climb/sink
- Pilots immediately see the "quality" of each thermal core
- Configurable scaling factor allows personal preference

**Alternatives Considered:**
1. Fixed circle size for all markers → Loss of information
2. Scale by circle count/duration → Less direct; doesn't reflect actual climb rate

**Selected:** Scale by vertical speed, with configurable factor

---

### Decision 8: MapLibre/PMTiles as Rendering Backend

**Rationale:**
- Already in use in BrandyFly for main flight screen
- Supports offline maps via PMTiles
- Circle marker rendering is straightforward (GeoJSON overlay)

**Alternatives Considered:**
1. Custom Canvas/OpenGL rendering → Duplicates work, harder to maintain
2. Google Maps → Requires API key, not offline-friendly

**Selected:** Extend existing MapLibre integration

---

## Architecture Sketch

```
┌─────────────────────────────────────────────────────┐
│ Flight Core (Rust) – crates/flight_core/            │
├─────────────────────────────────────────────────────┤
│                                                     │
│  ┌────────────────────────────────────────────┐   │
│  │ Thermaling Detection Module                │   │
│  │ • Circular pattern analyzer                │   │
│  │ • Vertical speed aggregator                │   │
│  │ • Episode state machine                    │   │
│  └────────────────────────────────────────────┘   │
│  ↓                                                 │
│  Emits: ThermaleEpisodeEvent, CircleMarkerEvent   │
└─────────────────────────────────────────────────────┘
            ↓
┌─────────────────────────────────────────────────────┐
│ Contracts (packages/contracts/)                     │
├─────────────────────────────────────────────────────┤
│ • ThermaleEpisode (ID, start/end, markers)         │
│ • CircleMarker (lat, lng, radius, color, v_rate)  │
│ • ThermaleConfig (duration_min, climb_min, scale) │
└─────────────────────────────────────────────────────┘
            ↓
┌─────────────────────────────────────────────────────┐
│ Mobile UI (Flutter) – apps/mobile/                  │
├─────────────────────────────────────────────────────┤
│                                                     │
│  ┌────────────────────────────────────────────┐   │
│  │ Thermaling Screen Widget                   │   │
│  │ • Observes flight core events (Riverpod)  │   │
│  │ • Renders MapLibre + circle overlays       │   │
│  │ • Loads thermaling-specific config         │   │
│  │ • Provides settings panel                  │   │
│  └────────────────────────────────────────────┘   │
│                                                     │
│  ┌────────────────────────────────────────────┐   │
│  │ Main Flight Screen                         │   │
│  │ • Existing implementation                  │   │
│  │ • Separate config storage                  │   │
│  └────────────────────────────────────────────┘   │
│                                                     │
│  ┌────────────────────────────────────────────┐   │
│  │ Screen Router                              │   │
│  │ • Observes ThermaleEpisodeEvent            │   │
│  │ • Auto-switches main → thermaling          │   │
│  │ • Grace period timer                       │   │
│  │ • Manual override controls                 │   │
│  └────────────────────────────────────────────┘   │
│                                                     │
│  ┌────────────────────────────────────────────┐   │
│  │ Local Config Service (SharedPreferences)   │   │
│  │ • Thermaling screen: map, widgets          │   │
│  │ • Main screen: separate config             │   │
│  │ • Thermaling detection thresholds          │   │
│  └────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
```

---

## Risks / Trade-offs

| Risk | Mitigation |
|------|-----------|
| **False positives in gusty/turbulent conditions** | Configurable detection thresholds; pilots can adjust sensitivity. Start with conservative defaults (5s, 5m). |
| **Battery drain from continuous circling detection** | Thermaling detection is lightweight (just time-series analysis of existing data); happens in flight core off UI thread. Benchmark on real devices. |
| **Screen switching jitter at thermal edges** | Grace period (10s default) prevents rapid toggling. Pilots can also lock to manual screen. |
| **Offline map unavailability for thermaling screen** | Pilot must pre-download offline maps; same as main screen. No change in UX or capability. |
| **Config storage on different devices (iOS/Android)** | Flutter's SharedPreferences abstracts platform differences; tested with both. Document any platform-specific quirks in implementation. |
| **Circle marker rendering performance on many markers** | MapLibre handles GeoJSON efficiently; stress test with 50–100 markers. If performance degrades, implement marker clustering. |

---

## Migration Plan

1. **Phase 1 (Flight Core):**
   - Implement thermaling detection module in `crates/flight_core/src/thermaling.rs`
   - Add ThermaleEpisode and CircleMarker types to `packages/contracts/`
   - Export new events from flight core

2. **Phase 2 (UI – Screen & Router):**
   - Create `apps/mobile/lib/screens/thermaling_screen.dart`
   - Implement screen router logic to observe flight core events and auto-switch
   - Connect to existing map (MapLibre) and widget framework

3. **Phase 3 (UI – Configuration):**
   - Implement thermaling settings panel (`apps/mobile/lib/screens/thermaling_settings.dart`)
   - Add SharedPreferences service for thermaling config storage
   - Integrate into main settings UI

4. **Phase 4 (Testing & Polish):**
   - Unit tests for circling detection algorithms (Rust)
   - Widget tests for screen switching and configuration
   - Integration tests with mock flight data (use existing local mock mode)
   - Benchmark battery/performance on real devices

5. **Rollback:**
   - Feature flag: disable thermaling detection if it causes issues (e.g., excessive false positives)
   - Existing main screen remains unmodified; pilots can opt out by not upgrading or via feature flag

---

## Open Questions

- **Exact circle sizing formula:** How should vertical speed map to radius? (e.g., 1 knot = 50 pixels, or logarithmic?) → Answer in tasks/implementation based on design feedback.
- **Widget selection for thermaling screen:** Which widgets are "must-have" vs. optional? → Determine during design review or let pilots fully configure.
- **Grace period duration:** Is 10 seconds appropriate, or should it be configurable? → Gather feedback from test flights.
- **Historical circle visibility:** Should old thermaling episodes (completed in prior flight) remain visible, or clear on new flight? → Depends on pilot preference; answer during Phase 2.
