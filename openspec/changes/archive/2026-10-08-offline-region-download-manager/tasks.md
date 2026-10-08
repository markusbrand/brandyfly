## Tasks

### RegionManagerService
- [x] Define `RegionCatalog`, `RegionEntry`, `RegionFile` data models with JSON serialization
- [x] Define `DownloadedRegion` model with local metadata (version, download date, checksums, file paths)
- [x] Implement `fetchCatalog()` with HTTP fetch, local caching, and offline fallback
- [x] Implement `getDownloadedRegions()` scanning local `regions/` directory
- [x] Implement `downloadRegion(regionId)` with background HTTP download, progress stream, and checksum verification
- [x] Implement download resume via HTTP range requests for interrupted downloads
- [x] Implement atomic swap of completed downloads (temp dir to active dir)
- [x] Implement `updateRegion(regionId)` preserving old data until new is verified
- [x] Implement `deleteRegion(regionId)` with file cleanup
- [x] Implement `getStorageUsage()` for total and per-region disk usage
- [x] Implement `isLocationCovered(lat, lon)` bounding box check against downloaded regions
- [x] Implement `getSuggestedRegions(lat, lon)` against cached catalog

### Region Manager UI
- [x] Create region manager settings screen with list of all regions (downloaded + available)
- [x] Implement region list items with name, description, status badge, size, version date
- [x] Implement download action button with progress indicator
- [x] Implement update action button with "Update available" badge
- [x] Implement delete action button with confirmation dialog
- [x] Add total storage usage bar at top of screen
- [x] Add pull-to-refresh for catalog update
- [x] Add navigation to region manager from main settings screen

### Pre-flight download prompt
- [x] Implement GPS coverage check on app foreground / significant GPS change
- [x] Create dismissable bottom sheet prompt with suggested regions and download sizes
- [x] Implement session-scoped dismissal (do not re-show until app restart or >50 km location change)
- [x] Wire prompt to region download action (tapping a suggested region starts download)

### Integration
- [x] Wire `RegionManagerService` into MapLibre source configuration (issue #84's MapWidget uses downloaded region paths)
- [x] Add region manager entry to app settings / navigation
