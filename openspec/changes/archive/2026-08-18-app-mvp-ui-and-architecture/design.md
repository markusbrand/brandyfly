## Context
The BrandyFly mobile application currently lacks the foundational UI layout, navigation, and state management logic needed to support its primary function as a flight instrument. As a paragliding vario app, it needs to handle real-time sensor streams, update the UI frequently without blocking the main thread or causing battery drain, and allow complex user-driven UI customization (moving widgets, adding screens).

## Goals / Non-Goals
**Goals:**
- Establish the state management architecture for Flutter (using `riverpod` for local state and sensor streams).
- Define the data model for User Screens and Widgets configuration to be easily serialized/deserialized (e.g., using `freezed` and `json_serializable`).
- Create a performant widget rendering system where high-frequency updates (e.g., altitude, vario) are localized to specific widgets.
- Implement the overarching navigation state (current screen, edit mode, settings overlay, thermal auto-transition).

**Non-Goals:**
- Implementation of the actual Bluetooth communication protocols (handled in `brandyfly_native`).
- Complex custom rendering for the map (we will use `flutter_map` or similar standard packages initially).

## Decisions

### State Management: Riverpod
- **Decision:** Use Riverpod for dependency injection and state management.
- **Rationale:** Riverpod provides a robust, compile-safe way to manage global state (like active screen index, current theme, sensor streams) while allowing localized rebuilds. It's well-suited for streaming high-frequency data from the Rust core or Native channels to specific UI widgets without rebuilding the entire screen.
- **Alternatives:** BLoC (more boilerplate for simple state, though good for complex events), Provider (lacks compile safety and can lead to runtime errors on missing providers).

### UI Configuration Serialization
- **Decision:** Model screens, widgets, navigation bar, and settings layout using Dart `freezed` classes and serialize them to local storage using `shared_preferences` or a local SQLite/Hive DB depending on size. Since configuration is relatively small (JSON), `shared_preferences` is sufficient for MVP. This data model will explicitly store the user's chosen visual style (e.g., via an `enum`) for each configurable component, allowing seamless switching between mockup options.
- **Rationale:** Easy to persist and reload across app restarts. Freezed provides immutability, which pairs perfectly with Riverpod. Using an enum for visual styles keeps the state type-safe and maps cleanly to the mockup options defined in the requirements.
- **Alternatives:** Direct JSON manipulation (error-prone), heavy local database like Isar (overkill for UI configs).

### High-Frequency Sensor Updates
- **Decision:** The Native layer (Kotlin/Swift) or Rust core will provide telemetry via Dart `Stream`s. Widgets will use `StreamProvider` or `StreamBuilder` to listen *only* to the specific telemetry they need.
- **Rationale:** Prevents the entire screen from rebuilding 10-50 times a second when the vario changes.
- **Alternatives:** Global state object that updates frequently (causes massive UI jank).

### Navigation & Routing
- **Decision:** Use a simple state-based router (e.g., `go_router` or just Riverpod state managing the main view) since the app is essentially a single-page app (SPA) with a configurable stack of views (screens) and overlays (settings, nav).
- **Rationale:** Traditional push/pop navigation doesn't fit the "swipe between N configurable screens" model well. We will use a `PageView` managed by a Riverpod state controller.
- **Alternatives:** Complex nested `Navigator` (too rigid for dynamic screens).

## Risks / Trade-offs

- **Risk: UI Thread blocking from high-frequency updates.** → Mitigation: Ensure telemetry processing happens in the Rust core or Isolates. The UI should only subscribe to processed, rate-limited (e.g., 60fps max) `Stream`s.
- **Risk: Widget overlapping issues in Edit Mode.** → Mitigation: Implement a robust z-index sorting mechanism when rendering the `Stack` of widgets.
- **Risk: Thermal screen transition jank.** → Mitigation: The auto-transition should be a smooth animation but must not block essential data. It should be driven by a distinct state flag `isThermaling` provided by the flight core.
