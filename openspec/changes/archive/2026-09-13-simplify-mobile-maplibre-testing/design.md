## Context

See `proposal.md` for motivation. The BrandyFly flight computer uses `maplibre: 0.3.6` which provides native GPU vector rendering on Android and iOS. Desktop Linux lacks a native MapLibre GL embedder, and Flutter Web dev servers reject byte-range requests required by PMTiles. Consequently, running development testing directly inside an Android Virtual Device (AVD) emulator on Linux and the iOS Simulator on macOS provides 100% behavioral parity with physical flight instruments.

## Goals / Non-Goals

**Goals:**
- Provide automated setup for the Android SDK command-line tools, platform-tools 34, and an accelerated x86_64 AVD emulator in user space (`~/Android/Sdk`).
- Eliminate `_AlpineReliefBackgroundPainter` and platform-check branches from `MapWidget`, mounting `MapLibreMap` directly.
- Streamline `MapLibreMapService` to focus cleanly on native mobile configuration.
- Revert experimental CDN script tags from `apps/mobile/web/index.html`.
- Update `GEMINI.md` to specify Android emulator / device testing.

**Non-Goals:**
- Porting or maintaining a C++ Linux desktop MapLibre GL engine.
- Supporting Flutter Web as an active flight deployment target.

## Decisions

### Decision 1: User-Space Android SDK and AVD Configuration
- **Choice**: Install Android SDK tools, platform-tools (API 34), and system image in `~/Android/Sdk` without requiring root/sudo permissions.
- **Rationale**: Keeps the workstation development environment self-contained, repeatable, and non-destructive.
- **Alternatives Considered**: System-wide package installation via `sudo pacman` (rejected because it requires user password input and intermixes Arch system packages with Flutter SDK management).

### Decision 2: Single Native Map Viewport in `MapWidget`
- **Choice**: Remove `_AlpineReliefBackgroundPainter` and mount `MapLibreMap` as the sole map viewport.
- **Rationale**: Eliminates dual-maintenance overhead and guarantees that developers only see and validate the real MapLibre GL vector styling and hillshade relief.
- **Alternatives Considered**: Retaining the canvas simulation as a silent fallback (rejected: masks platform differences and creates misleading testing feedback).

### Decision 3: Headless Widget Testing Compatibility
- **Choice**: Ensure widget tests (`flutter test`) continue to run smoothly by keeping `MapWidget` headless-friendly when mock controllers or test environments are active.

## Risks / Trade-offs

- **[System image download duration]** → Streamlined download of the minimal Google APIs x86_64 system image with automated background progress logging.
- **[KVM acceleration on Linux]** → Check `/dev/kvm` permissions to enable 60 FPS hardware-accelerated emulation on the AMD GPU.
