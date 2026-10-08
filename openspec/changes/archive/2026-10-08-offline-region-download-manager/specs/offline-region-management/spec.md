## ADDED Requirements

### Requirement: Region catalog browsing
The application SHALL fetch and display a catalog of available offline map regions from a remote server.

#### Scenario: Catalog loaded successfully
- **WHEN** the pilot opens the region manager screen with internet connectivity
- **THEN** the app displays a list of available regions with name, description, geographic coverage, download size, and version date

#### Scenario: Catalog fetch fails (offline)
- **WHEN** the pilot opens the region manager without internet connectivity
- **THEN** the app displays the last cached catalog (if available) or a message indicating that internet is required to browse available regions, without crashing or hanging

### Requirement: Region download with progress
The application SHALL download region PMTiles files in the background with visible progress indication.

#### Scenario: Initiating a region download
- **WHEN** the pilot taps "Download" on an available region
- **THEN** the download begins in the background, a progress bar shows bytes downloaded vs total, and the pilot can continue using the app normally

#### Scenario: Download completion
- **WHEN** a region download finishes and checksum verification passes
- **THEN** the region files are atomically moved to the active region storage, the region appears as "Downloaded" with a green status, and the map immediately renders from the new data

#### Scenario: Download interruption and resume
- **WHEN** a download is interrupted (network loss, app backgrounded)
- **THEN** the partial download is preserved and can be resumed when connectivity returns, without re-downloading already received data

#### Scenario: Checksum verification failure
- **WHEN** a downloaded file fails checksum verification
- **THEN** the corrupt file is deleted, the pilot is notified, and the download can be retried

### Requirement: Region update detection and execution
The application SHALL detect when newer versions of downloaded regions are available and allow the pilot to update them.

#### Scenario: Update available
- **WHEN** the catalog is refreshed and a downloaded region has a newer version on the server
- **THEN** the region displays an "Update available" badge with the new version date

#### Scenario: Updating a region
- **WHEN** the pilot taps "Update" on a region with an available update
- **THEN** the new version downloads in the background while the old version remains usable, and the old version is replaced atomically on successful completion

### Requirement: Region deletion and storage management
The application SHALL display storage usage and allow pilots to delete individual downloaded regions.

#### Scenario: Storage overview
- **WHEN** the pilot views the region manager
- **THEN** each downloaded region displays its storage size (map + terrain combined), and a total "Offline maps" storage usage is shown

#### Scenario: Deleting a region
- **WHEN** the pilot taps "Delete" on a downloaded region and confirms
- **THEN** the region's PMTiles files are removed from disk, storage is reclaimed, and the region returns to "Available for download" state
