## Why

BrandyFly is designed exclusively as an offline-first paragliding flight computer for Android and iOS mobile devices. Following the migration to MapLibre GL and offline PMTiles (`migrate-to-maplibre-pmtiles`), maintaining temporary fallback canvas rendering for Linux desktop or running in browser web contexts creates diverging behavior and misleading test results (such as HTTP range-request failures for PMTiles in Web and blank fallback canvases on desktop).

To ensure that testing on the development workstation (Garuda Linux or MacBook Pro) behaves identically to physical flight hardware, the development workflow must run directly on the genuine target environments: an Android Emulator (or USB physical device) on Linux, and the iOS Simulator on macOS. This enables removing all non-production canvas fallback and web stubbing code, keeping the codebase clean, robust, and maintainable.

## What Changes

- **Android Emulator & Toolchain Setup**: Configure local Android command-line tools, Android SDK platform 34, and a hardware-accelerated (KVM) x86_64 Android Virtual Device (AVD) on the Linux development PC.
- **Codebase Simplification**:
  - Remove `_AlpineReliefBackgroundPainter` and desktop platform branching from `apps/mobile/lib/widgets/flight/map_widget.dart`, directly mounting `MapLibreMap`.
  - Streamline `apps/mobile/lib/services/maplibre_map_service.dart` by removing desktop fallback checks.
  - Remove CDN MapLibre script and stylesheet tags from `apps/mobile/web/index.html`.
- **Guidelines Alignment**: Update `GEMINI.md` to specify Android Emulator / physical device as the authoritative local test execution target.

## Capabilities

### Modified Capabilities
- `offline-vector-map-rendering`: Focus map rendering specification strictly on native mobile targets (Android & iOS) and their authentic emulators, removing non-production desktop canvas fallback requirements.

## Impact

- `apps/mobile/lib/widgets/flight/map_widget.dart`: Streamlined widget hierarchy without mock canvas painting.
- `apps/mobile/lib/services/maplibre_map_service.dart`: Simplified service without platform fallback checks.
- `apps/mobile/web/index.html`: Restored clean standard web entrypoint.
- `GEMINI.md`: Aligned run instructions with the authentic Android testing workflow.
- `apps/mobile/test/`: Ensure all unit and widget tests continue to pass cleanly with mock or headless test configurations.
