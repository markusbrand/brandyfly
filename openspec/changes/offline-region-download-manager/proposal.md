## Summary

Add a region download manager that lets pilots browse, download, update, and delete offline map regions — curated by mountain-range flying areas — with storage management and a dismissable pre-flight download prompt when the pilot lacks map coverage for their current area.

## Problem Statement

After the MapLibre/PMTiles migration (issue #84), the app can render from local PMTiles files, but there is no mechanism for pilots to acquire those files. Without a region download manager, pilots must manually obtain and place PMTiles files — an unacceptable UX for a flying instrument. Pilots need a simple way to download map data for their flying area before leaving cell coverage, and to keep that data up to date.

## Proposed Solution

1. **Region Catalog**: Maintain a server-hosted `catalog.json` listing available flying-area regions with metadata (name, description, bounding box, file sizes, version, generation date, checksums). The app fetches this catalog to present available regions.
2. **Download Manager UI**: A settings screen where pilots can browse available regions, see download sizes, initiate downloads, monitor progress, and manage downloaded regions (update, delete).
3. **Background Downloads**: Region downloads proceed in the background with progress indication. The old region data remains usable during download; files are atomically swapped on completion.
4. **Update Detection**: On catalog refresh, compare local region versions against server versions. Show "Update available" badges on regions with newer data.
5. **Storage Management**: Display per-region and total storage usage. Allow pilots to delete individual regions to reclaim space.
6. **Pre-flight Download Prompt**: When the app detects the pilot's GPS location is outside any downloaded region, show a dismissable prompt suggesting relevant region downloads before the pilot loses connectivity. The prompt can be permanently dismissed per-region or globally.
7. **Region Granularity**: Regions are curated by mountain-range flying areas (not country borders), sized at ~50-180 MB each, with ~20 km overlap zones at boundaries for seamless XC flight coverage.

## Prerequisites

- **Issue #84** (`migrate-to-maplibre-pmtiles`) must be complete — the app must be rendering from local PMTiles before downloads are useful.
- **Issue #86** (`offline-map-data-pipeline`) should have at least a v1 catalog and initial regions hosted on CDN.

## Goals

- Let pilots download complete offline map regions with one tap.
- Provide clear storage usage visibility and per-region management (update, delete).
- Prompt pilots about missing map coverage before they leave connectivity, without being intrusive.
- Support background downloads that do not block the flight UI.
- Enable atomic region updates that keep old data usable until new data is verified.

## Non-Goals

- Custom bounding box downloads (may be added as a future power-user feature).
- Differential/incremental region updates (full re-download is sufficient for monthly refreshes at 50-180 MB).
- Auto-downloading regions without pilot consent.
- Region generation or hosting infrastructure (separate change: `offline-map-data-pipeline`).

## Capabilities

### New Capabilities

- `offline-region-management`: Browse, download, update, and delete offline map regions from a curated catalog of mountain-range flying areas.
- `pre-flight-coverage-check`: Detect missing map coverage at the pilot's GPS location and prompt for region download before flight.

### Modified Capabilities

None.

## Impact

- **New screens**: Region manager settings screen with download/update/delete controls and storage usage display.
- **Network**: Requires internet connectivity for catalog fetch and region downloads (CDN). All downloads are user-initiated.
- **Storage**: Each region is ~50-180 MB. Multiple regions can be downloaded simultaneously.
- **Privacy**: No GPS coordinates are sent to the catalog server. Catalog fetches and region downloads are anonymous HTTPS GET requests to a CDN.
