## 1. Setup & Architecture Framework

- [ ] 1.1 Update `apps/mobile/pubspec.yaml` to include necessary dependencies: `flutter_riverpod`, `freezed_annotation`, `json_serializable`, `shared_preferences`, `flutter_localizations`.
- [ ] 1.2 Implement the core UI data models using `freezed` (WidgetConfig, ScreenConfig, AppConfig).
- [ ] 1.3 Implement `shared_preferences` persistence logic for AppConfig and Screen configurations.
- [ ] 1.4 Set up basic Riverpod providers for ThemeMode, Locale, and Navigation State.
- [ ] 1.5 Add validation to ensure AppConfig successfully serializes and deserializes from storage.

## 2. Navigation & Layout

- [ ] 2.1 Implement the swipe-down main navigation bar overlay with adjustable opacity.
- [ ] 2.2 Implement the Settings screen route (accessible from nav bar) that returns to previous context on dismiss.
- [ ] 2.3 Implement the `PageView` based main screen swiping mechanism.
- [ ] 2.4 Add validation by writing a Flutter widget test ensuring swipe-down reveals the nav bar and settings navigation works.

## 3. Edit Mode & Widget System

- [ ] 3.1 Implement "Edit Mode" state in Riverpod, toggled from the nav bar.
- [ ] 3.2 Create the base Draggable/Resizable widget container that reads/writes its position, size, z-index, and transparency to the Riverpod state.
- [ ] 3.3 Implement UI controls within Edit Mode to add new screens, remove screens, and add widgets.
- [ ] 3.4 Add validation ensuring widget position updates in Edit Mode are correctly persisted to the `ScreenConfig`.

## 4. Telemetry & Flight Widgets

- [ ] 4.1 Define placeholder `Stream` providers for telemetry data (Altitude, Groundspeed, Vario, Wind) falling back from a Mock Bluetooth source to a Mock Internal source.
- [ ] 4.2 Implement the Altitude widget.
- [ ] 4.3 Implement the Groundspeed widget.
- [ ] 4.4 Implement the Vario (lift/sink rate) widget with visual red/green bars.
- [ ] 4.5 Add validation tests to ensure Vario widget renders green for positive inputs and red for negative inputs.
- [ ] 4.6 Implement the Map background widget stub (using a simple placeholder or `flutter_map` base).

## 5. Thermaling Screen Logic

- [ ] 5.1 Implement the thermal state provider (listening to a mock flight core event).
- [ ] 5.2 Implement the auto-transition logic in the main router: when `isThermaling` is true, push/switch to the Thermaling Screen.
- [ ] 5.3 Implement the auto-revert logic: when `isThermaling` becomes false, return to the previous screen index.
- [ ] 5.4 Add validation test to mock `isThermaling` state changes and verify the screen index updates correctly.

## 6. Settings & Localization

- [ ] 6.1 Implement the Settings UI (Bluetooth stub, XContest account stub, Theme toggle, Language toggle, Nav opacity slider, Version info).
- [ ] 6.2 Set up `flutter_localizations` with English and German ARB files.
- [ ] 6.3 Implement light/dark theme data in Flutter and bind it to the ThemeMode provider.
- [ ] 6.4 Add validation test ensuring the app switches between English and German text when the locale provider is updated.
