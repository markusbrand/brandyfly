# Proposal: Sync Untracked Catalog Fallback and Device Workflows

## Why
Multiple operational improvements and offline reliability enhancements were committed directly to the codebase (PR #252, #265, and #270) without prior OpenSpec change tracking. Synchronizing these changes into OpenSpec formalizes the specifications for bundled region catalog fallbacks, thermal prefetch bounds guards, and multi-platform device run conventions across Garuda PC and macOS workstations.

## What Changes
- **Offline Region Management**:
  - Add bundled asset seed catalog (`assets/map_data/catalog.json`) fallback in `RegionManagerService` when remote network fetch fails and no cached catalog exists in app support storage.
- **Thermal Tile Prefetch**:
  - Add regional bounding box fallback resolution from `meta.json` alongside catalog metadata and PMTiles archive headers.
  - Add runaway tile count threshold protection skipping thermal prefetch when a region's calculated tile count exceeds 25,000 tiles.
- **Headless Device Workflows**:
  - Update execution target resolution to document local GPU emulator conventions on Garuda PC workstations (`brandyfly_test_device`).
  - Document macOS local clone and iOS Simulator workflows via Xcode Device Hub.

## Non-Goals
- Changing the underlying PMTiles vector map parser or DEM elevation engine.
- Modifying remote catalog distribution infrastructure or CDN endpoints.
- Introducing new platform emulator scripts outside the existing shell tooling.

## Capabilities

### Modified Capabilities
- `offline-region-management`: Support fallback to bundled asset seed catalog (`assets/map_data/catalog.json`) when offline and no disk cache exists.
- `thermal-tile-prefetch`: Support `meta.json` regional bounds extraction and protect against runaway tile prefetch exceeding 25,000 tiles.
- `headless-device-workflows`: Expand execution target resolution to cover local GPU emulator on Garuda PC and iOS Simulator via Xcode Device Hub on macOS.

## Impact
- **Affected code**: `apps/mobile/lib/services/region_manager_service.dart`, `apps/mobile/assets/map_data/catalog.json`, `apps/mobile/lib/data/thermal/region_bounds_provider.dart`, `apps/mobile/lib/services/thermal_prefetch_service.dart`, `AGENTS.md`, `GEMINI.md`, `docs/development.md`.
- **Offline & Safety Impact**: Enhances flight safety and app reliability when first launched completely offline without internet connectivity.
- **Privacy & Licensing**: Retains zero-telemetry offline contracts and complies with OpenStreetMap and Copernicus open data licensing.
