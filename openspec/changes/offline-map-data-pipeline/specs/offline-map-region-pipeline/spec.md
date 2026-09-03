## ADDED Requirements

### Requirement: Vector tile generation from OSM data
The pipeline SHALL generate OpenMapTiles-schema vector tile PMTiles archives from OpenStreetMap PBF extracts for each defined region.

#### Scenario: Region vector tiles generated
- **WHEN** the pipeline runs for a defined region with a valid bounding box
- **THEN** it produces a PMTiles archive containing vector tiles at zoom levels 0-14 with OpenMapTiles layer schema (transportation, water, landuse, place, poi, boundary, etc.)

#### Scenario: Overlap margins applied
- **WHEN** a region bounding box has defined overlap margins
- **THEN** the generated tiles extend beyond the nominal region bounds by the specified margin (~20 km) to ensure seamless rendering at region borders

### Requirement: Terrain DEM tile generation
The pipeline SHALL generate terrain-RGB encoded raster tile PMTiles archives from Copernicus GLO-30 DEM data for each defined region.

#### Scenario: Terrain tiles generated
- **WHEN** the pipeline processes Copernicus GLO-30 GeoTIFF source data for a region
- **THEN** it produces a PMTiles archive containing terrain-RGB raster tiles at zoom levels 0-12, where each pixel encodes elevation as `elevation = -10000 + ((R * 65536 + G * 256 + B) * 0.1)` meters

#### Scenario: DEM data coverage
- **WHEN** the Copernicus GLO-30 dataset has gaps or no-data areas within a region
- **THEN** the pipeline fills no-data pixels with a sentinel value (sea level = 0m encoded as RGB) and logs the affected areas

### Requirement: Catalog generation with checksums
The pipeline SHALL produce a versioned catalog.json with metadata, file URLs, sizes, and SHA-256 checksums for all regions.

#### Scenario: Catalog generated
- **WHEN** all region packages are built
- **THEN** a catalog.json is produced containing: catalog version, generation timestamp, and for each region: ID, name, description, bounding box, version string, generation date, and per-file (map + terrain) URL, byte size, and SHA-256 checksum

### Requirement: CDN publishing
The pipeline SHALL upload all generated files to object storage accessible via anonymous HTTPS GET requests.

#### Scenario: Files published
- **WHEN** generation and checksumming completes
- **THEN** all PMTiles files and catalog.json are uploaded to the configured object storage bucket with correct content types and public read access

### Requirement: Monthly automated execution
The pipeline SHALL run automatically on a monthly schedule via CI.

#### Scenario: Scheduled run
- **WHEN** the monthly CI schedule triggers
- **THEN** the pipeline downloads fresh OSM extracts from Geofabrik, regenerates all regions, and publishes updated files to CDN

#### Scenario: On-demand run
- **WHEN** a developer manually triggers the CI workflow
- **THEN** the pipeline runs identically to the scheduled execution

### Requirement: Licensing compliance
The pipeline SHALL include proper attribution metadata for all source datasets.

#### Scenario: Attribution in catalog
- **WHEN** catalog.json is generated
- **THEN** it includes attribution entries for OpenStreetMap (ODbL), Copernicus GLO-30 (CC-BY-4.0, ESA), and Natural Earth (public domain)
