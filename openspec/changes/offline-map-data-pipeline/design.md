## Context

This pipeline is the server-side counterpart to the app-side offline map changes. It can be developed in parallel with the MapLibre migration (issue #84) since the PMTiles format is a well-defined standard. The pipeline produces files that the region download manager (issue #85) fetches and the ElevationService (issue #86) reads.

## Architecture Decisions

### 1. Tool chain

| Stage | Tool | Input | Output |
|---|---|---|---|
| OSM extract download | curl/wget | Geofabrik mirrors | Regional PBF files |
| Vector tile generation | Planetiler (Java) | PBF + region bbox | map.pmtiles |
| DEM source download | curl/wget | Copernicus GLO-30 AWS/ESA | GeoTIFF tiles |
| DEM merge + crop | GDAL (gdalwarp, gdal_merge) | GeoTIFF tiles + region bbox | Regional DEM GeoTIFF |
| Terrain-RGB encoding | rio-rgbify (rasterio) | DEM GeoTIFF | Terrain-RGB MBTiles/tiles |
| Terrain PMTiles packaging | pmtiles CLI (go-pmtiles) | Terrain-RGB tiles | terrain.pmtiles |
| Global fallback | Planetiler | Natural Earth shapefile | fallback.pmtiles |
| Catalog generation | Custom script (Python/bash) | All region outputs | catalog.json |
| CDN upload | rclone or aws-cli | All outputs | Cloudflare R2 bucket |

### 2. Region definition config

`tools/map-pipeline/regions.yaml`:

```yaml
regions:
  - id: alps-east
    name: "Alps - Eastern"
    description: "Eastern Austria, Slovenia, SE Bavaria (Dachstein, Karawanken, Julian Alps)"
    bounds:
      north: 48.3
      south: 46.2
      west: 12.5
      east: 16.6
    overlapKm: 20
    osmSource: "europe/austria"  # Geofabrik extract to use (clipped to bounds)

  - id: alps-central
    name: "Alps - Central"
    description: "Tyrol, Vorarlberg, eastern Switzerland, Allgaeu (Stubai, Zillertal, Arlberg, Engadin)"
    bounds:
      north: 47.8
      south: 46.2
      west: 9.5
      east: 12.8
    overlapKm: 20
    osmSource: "europe/alps"

  # ... additional regions
```

### 3. Output structure on CDN

```
r2-bucket/
  catalog.json
  regions/
    alps-east/
      map.pmtiles
      terrain.pmtiles
    alps-central/
      map.pmtiles
      terrain.pmtiles
    ...
  fallback/
    overview.pmtiles
```

### 4. Hosting on Cloudflare R2

- Free egress (no per-GB download cost)
- S3-compatible API for upload via rclone
- Public bucket with custom domain or R2.dev URL
- Estimated storage: ~5 GB total for v1 catalog (8 regions x ~600 MB avg for map+terrain)
- Estimated cost: ~0.08 USD/month storage only

### 5. CI workflow

GitHub Actions workflow `.github/workflows/map-pipeline.yml`:
- Trigger: monthly cron schedule + manual dispatch
- Runner: ubuntu-latest with Java (Planetiler), Python (rasterio/rio-rgbify), GDAL, Go (pmtiles CLI)
- Steps: download sources, generate per-region, checksum, generate catalog, upload to R2
- Artifacts: build logs, checksums, catalog snapshot
- Secrets: R2 credentials (access key, secret key, bucket URL)
- Estimated runtime: 30-60 minutes for full 8-region build

### 6. Versioning

- Region version string: `YYYY-MM` (e.g., `2026-08`)
- Catalog carries `generatedAt` ISO 8601 timestamp
- Previous versions are NOT retained on CDN (full replacement on each pipeline run)
- App compares local `meta.json` version against catalog version to detect updates
