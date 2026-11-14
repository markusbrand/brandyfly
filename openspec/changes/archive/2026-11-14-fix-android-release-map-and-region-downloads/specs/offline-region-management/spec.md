# offline-region-management Specification Delta

## MODIFIED Requirements

### Requirement: Region catalog browsing
The application SHALL fetch and display a catalog of available offline map regions from the published GitHub Releases catalog endpoint (`https://github.com/markusbrand/brandyfly/releases/download/maps-v1/catalog.json` by default), falling back to a cached catalog or bundled asset seed catalog (`assets/map_data/catalog.json`) when offline.

#### Scenario: Catalog loaded successfully
- **WHEN** the pilot opens the region manager screen with internet connectivity
- **THEN** the app displays a list of available regions with name, description, geographic coverage, download size, and version date

#### Scenario: Catalog fetch fails (offline)
- **WHEN** the pilot opens the region manager without internet connectivity
- **THEN** the app displays the last cached catalog (if available) or falls back to the bundled seed catalog, without crashing or hanging

#### Scenario: Fallback to bundled seed catalog
- **WHEN** the app starts offline for the first time without a cached catalog on disk
- **THEN** the application loads the bundled asset seed catalog and displays default curated offline regions

### Requirement: Region download with progress
The application SHALL download region PMTiles files in the background with visible progress indication and strict integrity verification. The application SHALL NOT substitute bundled overview stub files when a remote region download fails due to DNS, socket, or HTTP errors.

#### Scenario: Initiating a region download
- **WHEN** the pilot taps "Download" on an available region
- **THEN** the download begins in the background, following HTTP redirects as needed, a progress bar shows bytes downloaded vs total, and the pilot can continue using the app normally

#### Scenario: Download completion
- **WHEN** a region download finishes, each downloaded PMTiles file is at least 4,096 bytes with a valid PMTiles v3 header, and SHA-256 checksum verification passes
- **THEN** the region files are atomically moved to the active region storage, `meta.json` records the actual verified disk byte size, the region appears as "Downloaded" with a green status, and the map immediately renders from the new data

#### Scenario: Network or host failure during region download
- **WHEN** a region download fails due to DNS resolution failure, connection refusal, timeout, or non-2xx HTTP status
- **THEN** the service transitions the download status to `failed` with a clear error message, does NOT copy `assets/map_data/global_overview.pmtiles` into the region directory, and leaves the region as not downloaded (or preserves the previous valid active version during an update)

#### Scenario: Download interruption and resume
- **WHEN** a download is interrupted (network loss, app backgrounded) after receiving partial bytes
- **THEN** the partial download is preserved in `.downloading` and can be resumed via HTTP `Range` headers when connectivity returns, without re-downloading already received data

#### Scenario: Checksum verification failure
- **WHEN** a downloaded file fails SHA-256 checksum verification or is smaller than 4,096 bytes / lacks a valid PMTiles v3 magic header
- **THEN** the corrupt or stub file is deleted, the download status transitions to `failed`, the pilot is notified, and the download can be retried

### Requirement: Region deletion and storage management
The application SHALL display accurate on-disk storage usage and allow pilots to delete individual downloaded regions. Previously written stub or corrupted region directories (`map.pmtiles` smaller than 4,096 bytes) SHALL be automatically excluded and cleaned up when enumerating downloaded regions.

#### Scenario: Storage overview
- **WHEN** the pilot views the region manager
- **THEN** each valid downloaded region displays its actual on-disk storage size (map + terrain combined), and a total "Offline maps" storage usage is shown

#### Scenario: Self-healing invalid or stub region directories
- **WHEN** `getDownloadedRegions()` encounters a region directory whose `map.pmtiles` is smaller than 4,096 bytes (such as a 499-byte synthetic stub from an earlier version)
- **THEN** the invalid region directory is deleted and excluded from the downloaded regions list so the pilot can download the real region archive

#### Scenario: Deleting a region
- **WHEN** the pilot taps "Delete" on a downloaded region and confirms
- **THEN** the region's PMTiles files are removed from disk, storage is reclaimed, and the region returns to "Available for download" state
