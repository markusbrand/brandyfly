## Tasks

### Pipeline scaffolding
- [x] Create `tools/map-pipeline/` directory with pipeline scripts
- [x] Create `tools/map-pipeline/regions.yaml` region definition config with v1 catalog regions (alps-east, alps-central, alps-west, alps-south, pyrenees, balkans-west, turkey-aegean, carpathians)
- [x] Document tool dependencies and versions (Planetiler, GDAL, rasterio, rio-rgbify, go-pmtiles, rclone)

### Vector tile generation
- [x] Script to download Geofabrik OSM PBF extracts for each region's source area
- [x] Script to run Planetiler with OpenMapTiles profile, clipped to region bbox + overlap margin, output as PMTiles (zoom 0-14)
- [x] Verify generated PMTiles render correctly in MapLibre with the Alpine Relief style

### Terrain DEM generation
- [x] Script to download Copernicus GLO-30 GeoTIFF tiles covering each region
- [x] Script to merge and crop DEM tiles to region bbox + overlap using GDAL
- [x] Script to encode DEM as terrain-RGB using rio-rgbify
- [x] Script to package terrain-RGB tiles as PMTiles using go-pmtiles CLI (zoom 0-12)
- [x] Verify terrain PMTiles render hillshade in MapLibre and decode correctly for elevation queries

### Global fallback
- [x] Script to generate low-zoom (0-6) global overview PMTiles from Natural Earth data using Planetiler
- [x] Verify fallback PMTiles size is under 5 MB and renders basic continent/water outlines

### Catalog and checksums
- [x] Script to compute SHA-256 checksums for all generated PMTiles files
- [x] Script to generate catalog.json with region metadata, file URLs, sizes, checksums, and attribution
- [x] Validate catalog.json schema against the app's expected format

### CDN publishing
- [x] Set up Cloudflare R2 bucket with public read access
- [x] Script to upload all PMTiles and catalog.json to R2 via rclone
- [x] Verify files are accessible via anonymous HTTPS GET

### CI automation
- [x] Create `.github/workflows/map-pipeline.yml` with monthly cron trigger and manual dispatch
- [x] Configure GitHub Actions secrets for R2 credentials
- [x] Add pipeline execution steps (download, generate, checksum, catalog, upload)
- [x] Add build artifact upload (logs, checksums, catalog snapshot)
- [x] Test full pipeline run end-to-end with at least one region

### Licensing and attribution
- [x] Include ODbL (OSM), CC-BY-4.0 (Copernicus), and public domain (Natural Earth) attribution in catalog.json
- [x] Update THIRD_PARTY_DATA.md with pipeline data source details
