## 1. Android Development Toolchain & Emulator Setup

- [x] 1.1 Download and configure Android SDK command-line tools into `~/Android/Sdk` and verify `sdkmanager --version` runs.
- [x] 1.2 Install Android SDK platform-tools, platforms 34, build-tools 34.0.0, and emulator components.
- [x] 1.3 Download system image `system-images;android-34;google_apis;x86_64` and accept Android SDK licenses via `flutter doctor --android-licenses`.
- [x] 1.4 Create an AVD named `brandyfly_test_device` using `avdmanager` and verify it is listed in `flutter emulators`.
- [x] 1.5 Boot the emulator and verify device connectivity via `adb devices`.

## 2. Codebase Simplification

- [x] 2.1 Remove `_AlpineReliefBackgroundPainter` and `isPlatformSupported` conditional branching in `apps/mobile/lib/widgets/flight/map_widget.dart` so `MapLibreMap` is mounted as the sole native map viewport.
- [x] 2.2 Clean up `apps/mobile/lib/services/maplibre_map_service.dart` by removing redundant desktop fallback branches.
- [x] 2.3 Revert external MapLibre CDN script tags in `apps/mobile/web/index.html`.
- [x] 2.4 Update `GEMINI.md` to reflect Android Emulator / device and iOS Simulator as the primary testing runbooks.

## 3. Verification & Validation

- [x] 3.1 Run `flutter test` across `apps/mobile` to verify all unit and widget tests pass.
- [x] 3.2 Execute `flutter run -d android` on the running emulator and verify genuine MapLibre GL offline vector map rendering with Copernicus DEM hillshade and flight overlays.
- [x] 3.3 Run `npx openspec validate --all --strict` to ensure OpenSpec specification validity.
