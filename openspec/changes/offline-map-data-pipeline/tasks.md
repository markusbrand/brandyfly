## Tasks

### Pipeline scaffolding
- [ ] Create `tools/map-pipeline/` directory with pipeline scripts
- [ ] Create `tools/map-pipeline/regions.yaml` region definition config with v1 catalog regions (alps-east, alps-central, alps-west, alps-south, pyrenees, balkans-west, turkey-aegean, carpathians)
- [ ] Document tool dependencies and versions (Planetiler, GDAL, rasterio, rio-rgbify, go-pmtiles, rclone)

### Vector tile generation
- [ ] Script to download Geofabrik OSM PBF extracts for each region's source area
- [ ] Script to run Planetiler with OpenMapTiles profile, clipped to region bbox + overlap margin, output as PMTiles (zoom 0-14)
- [ ] Verify generated PMTiles render correctly in MapLibre with the Alpine Relief style

### Terrain DEM generation
- [ ] Script to download Copernicus GLO-30 GeoTIFF tiles covering each region
- [ ] Script to merge and crop DEM tiles to region bbox + overlap using GDAL
- [ ] Script to encode DEM as terrain-RGB using rio-rgbify
- [ ] Script to package terrain-RGB tiles as PMTiles using go-pmtiles CLI (zoom 0-12)
- [ ] Verify terrain PMTiles render hillshade in MapLibre and decode correctly for elevation queries

### Global fallback
- [ ] Script to generate low-zoom (0-6) global overview PMTiles from Natural Earth data using Planetiler
- [ ] Verify fallback PMTiles size is under 5 MB and renders basic continent/water outlines

### Catalog and checksums
- [ ] Script to compute SHA-256 checksums for all generated PMTiles files
- [ ] Script to generate catalog.json with region metadata, file URLs, sizes, checksums, and attribution
- [ ] Validate catalog.json schema against the app's expected format

### CDN publishing
- [ ] Set up Cloudflare R2 bucket with public read access
- [ ] Script to upload all PMTiles and catalog.json to R2 via rclone
- [ ] Verify files are accessible via anonymous HTTPS GET

### CI automation
- [ ] Create `.github/workflows/map-pipeline.yml` with monthly cron trigger and manual dispatch
- [ ] Configure GitHub Actions secrets for R2 credentials
- [ ] Add pipeline execution steps (download, generate, checksum, catalog, upload)
- [ ] Add build artifact upload (logs, checksums, catalog snapshot)
- [ ] Test full pipeline run end-to-end with at least one region

### Licensing and attribution
- [ ] Include ODbL (OSM), CC-BY-4.0 (Copernicus), and public domain (Natural Earth) attribution in catalog.json
- [ ] Update THIRD_PARTY_DATA.md with pipeline data source details
