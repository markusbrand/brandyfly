## MODIFIED Requirements

### Requirement: Region catalog browsing
The application SHALL fetch and display a catalog of available offline map regions from a remote server. When network access is unavailable and no cached catalog exists in local app storage, the application SHALL fall back to a bundled asset seed catalog (`assets/map_data/catalog.json`) to allow offline region browsing without crashes or network blocking.

#### Scenario: Catalog loaded successfully
- **WHEN** the pilot opens the region manager screen with internet connectivity
- **THEN** the app displays a list of available regions with name, description, geographic coverage, download size, and version date

#### Scenario: Catalog fetch fails (offline)
- **WHEN** the pilot opens the region manager without internet connectivity
- **THEN** the app displays the last cached catalog (if available) or falls back to the bundled seed catalog, without crashing or hanging

#### Scenario: Fallback to bundled seed catalog
- **WHEN** the app starts offline for the first time without a cached catalog on disk
- **THEN** the application loads the bundled asset seed catalog and displays default curated offline regions
