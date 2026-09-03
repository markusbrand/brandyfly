## Tasks

### RegionManagerService
- [ ] Define `RegionCatalog`, `RegionEntry`, `RegionFile` data models with JSON serialization
- [ ] Define `DownloadedRegion` model with local metadata (version, download date, checksums, file paths)
- [ ] Implement `fetchCatalog()` with HTTP fetch, local caching, and offline fallback
- [ ] Implement `getDownloadedRegions()` scanning local `regions/` directory
- [ ] Implement `downloadRegion(regionId)` with background HTTP download, progress stream, and checksum verification
- [ ] Implement download resume via HTTP range requests for interrupted downloads
- [ ] Implement atomic swap of completed downloads (temp dir to active dir)
- [ ] Implement `updateRegion(regionId)` preserving old data until new is verified
- [ ] Implement `deleteRegion(regionId)` with file cleanup
- [ ] Implement `getStorageUsage()` for total and per-region disk usage
- [ ] Implement `isLocationCovered(lat, lon)` bounding box check against downloaded regions
- [ ] Implement `getSuggestedRegions(lat, lon)` against cached catalog

### Region Manager UI
- [ ] Create region manager settings screen with list of all regions (downloaded + available)
- [ ] Implement region list items with name, description, status badge, size, version date
- [ ] Implement download action button with progress indicator
- [ ] Implement update action button with "Update available" badge
- [ ] Implement delete action button with confirmation dialog
- [ ] Add total storage usage bar at top of screen
- [ ] Add pull-to-refresh for catalog update
- [ ] Add navigation to region manager from main settings screen

### Pre-flight download prompt
- [ ] Implement GPS coverage check on app foreground / significant GPS change
- [ ] Create dismissable bottom sheet prompt with suggested regions and download sizes
- [ ] Implement session-scoped dismissal (do not re-show until app restart or >50 km location change)
- [ ] Wire prompt to region download action (tapping a suggested region starts download)

### Integration
- [ ] Wire `RegionManagerService` into MapLibre source configuration (issue #84's MapWidget uses downloaded region paths)
- [ ] Add region manager entry to app settings / navigation
