# Technical Design: Sync Untracked Catalog Fallback and Device Workflows

## Context
See `proposal.md` for background and motivation. Several offline reliability mechanisms and developer workflow conventions were previously introduced directly into `apps/mobile` and project documentation. This design formalizes the technical patterns behind these changes to preserve long-term maintainability and traceability.

## Goals / Non-Goals

**Goals:**
- Provide reliable catalog bootstrapping in `RegionManagerService` even on cold, completely offline app launches.
- Prevent runaway prefetch memory/disk consumption by checking region bounds and tile counts before querying `thermal.kk7.ch`.
- Clearly specify developer run targets across headless servers, Linux desktops, and macOS workstations.

**Non-Goals:**
- Changing PMTiles archive formats or remote CDN infrastructure.
- Modifying thermal heatmap visualization shaders or color ramps.
- Rewriting ADB or simulator launch scripts.

## Decisions

### 1. Bundled Seed Catalog Asset Fallback
- **Choice**: Load `assets/map_data/catalog.json` via Flutter's `rootBundle` when remote network fetch fails and no cached catalog exists in app support storage.
- **Rationale**: Reuses the standard `RegionCatalog.fromJson` deserializer, ensures identical data structures between network and offline modes, and provides immediate sample mountain regions for offline pilots.
- **Alternatives Considered**: Hardcoded Dart models (diverges from catalog JSON schema, hard to update).

### 2. Guarding Runaway Thermal Prefetch with 25k Tile Threshold
- **Choice**: Calculate the tile count using `ThermalPrefetchPlanner.tileCount(region.bounds)` before executing prefetch. If `count > 25000`, skip prefetching with an informative log message.
- **Rationale**: A large or ill-defined bounding box could trigger hundreds of thousands of HTTP requests, violating rate limits and exhausting device storage.
- **Alternatives Considered**: Dynamically reducing max zoom level (creates inconsistent pilot experience across regions).

### 3. Regional Bounds Extraction Fallback Hierarchy
- **Choice**: Check region catalog metadata bounds first, then local `meta.json` inside the region directory, and finally parse the PMTiles header.
- **Rationale**: Maximizes robustness when regions are imported manually or downloaded without full metadata.

### 4. Multi-Platform Execution Target Resolution
- **Choice**: Document explicit run commands per environment (Bosgame server targeting Garuda emulator or physical device; Garuda PC targeting local emulator; macOS targeting iOS Simulator via Device Hub).
- **Rationale**: Eliminates guesswork for automated agents and developers across different workstations.

## Risks / Trade-offs

- **[Risk: Outdated bundled seed catalog]** → *Mitigation:* The remote catalog is fetched whenever online connectivity is detected, and any successful fetch immediately updates the persistent disk cache.
- **[Risk: Large regions skipping thermal prefetch]** → *Mitigation:* Clear log messages inform developers and pilots if a region exceeds the 25,000 tile threshold.
