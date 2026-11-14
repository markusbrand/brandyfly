# offline-map-region-pipeline Specification Delta

## MODIFIED Requirements

### Requirement: Vector tile generation from OSM data
The pipeline SHALL generate OpenMapTiles-schema vector tile PMTiles v3 archives from OpenStreetMap PBF extracts and global overview sources for each defined region using disk-backed memory-mapped storage (`--storage=mmap`) and specification-compliant PMTiles v3 directory offset varint encoding.

#### Scenario: Region vector tiles generated
- **WHEN** the pipeline runs for a defined region with a valid bounding box
- **THEN** it produces a PMTiles archive containing vector tiles at zoom levels 0-14 with OpenMapTiles layer schema (transportation, water, landuse, place, poi, boundary, etc.) using `--storage=mmap` without exhausting JVM heap memory during stage `osm`

#### Scenario: Overlap margins applied
- **WHEN** a region bounding box has defined overlap margins
- **THEN** the generated tiles extend beyond the nominal region bounds by the specified margin (~20 km) to ensure seamless rendering at region borders

#### Scenario: Specification-compliant directory offset encoding
- **WHEN** the pipeline or fallback generator writes directory entry tile offsets
- **THEN** contiguous entries (`offset == prev_offset + prev_length`) SHALL be encoded as varint `0`
- **AND** non-contiguous entries or the initial entry SHALL be encoded as absolute `offset + 1`
- **AND** tile deduplication where an entry points to an earlier byte offset SHALL NOT cause negative integer inputs to varint encoding or infinite loops

### Requirement: Catalog generation with checksums
The pipeline SHALL produce a versioned `catalog.json` with metadata, file URLs, sizes, and SHA-256 checksums for all regions, supporting both flat release asset URLs (`{base_url}/{region_id}-map.pmtiles`, `{base_url}/{region_id}-terrain.pmtiles`) for GitHub Releases and hierarchical object storage paths.

#### Scenario: Catalog generated
- **WHEN** all region packages are built
- **THEN** a `catalog.json` is produced containing: catalog version, generation timestamp, and for each region: ID, name, description, bounding box, version string, generation date, and per-file (map + terrain) URL, actual byte size, and SHA-256 checksum

#### Scenario: Flat GitHub Releases URL layout
- **WHEN** `cdn_base_url` points to a GitHub Releases download base (`https://github.com/<owner>/<repo>/releases/download/<tag>`) or `--flat-urls` is enabled
- **THEN** `generate_catalog.py` emits flat asset URLs (`{cdn_base_url}/{region_id}-map.pmtiles`, `{cdn_base_url}/{region_id}-terrain.pmtiles`, and `{cdn_base_url}/overview.pmtiles`) matching the GitHub Release asset filenames

### Requirement: CDN publishing
The pipeline SHALL publish generated PMTiles archives and `catalog.json` to publicly accessible HTTPS storage via GitHub Releases (`maps-v1` tag) using `GITHUB_TOKEN`, and optionally to Cloudflare R2 when R2 credentials are configured.

#### Scenario: Files published
- **WHEN** generation and checksumming complete in CI or via the release publishing script
- **THEN** all regional PMTiles files (named `<region_id>-map.pmtiles` and `<region_id>-terrain.pmtiles`), `overview.pmtiles`, `checksums.sha256`, and `catalog.json` are uploaded to the `maps-v1` GitHub Release with `--clobber` so anonymous HTTPS GET requests from the mobile app can download them immediately without external R2 secrets

#### Scenario: Optional Cloudflare R2 upload
- **WHEN** Cloudflare R2 credentials (`R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`) are also configured
- **THEN** the pipeline additionally uploads the generated files to the configured R2 bucket
