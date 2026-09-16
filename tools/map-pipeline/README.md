# BrandyFly Offline Map Data Pipeline

Automated pipeline that generates offline map region packages (OpenMapTiles vector PMTiles and terrain-RGB DEM PMTiles) from OpenStreetMap and Copernicus GLO-30 DEM sources, creates a versioned `catalog.json` with SHA-256 checksums, and publishes them to CDN (Cloudflare R2).

## Tool Dependencies and Versions

The pipeline requires the following tools pinned and configured:

| Tool | Version | Purpose | Installation / Source |
|---|---|---|---|
| **Java** | 21+ | Runtime for Planetiler | `openjdk-21-jdk` |
| **Planetiler** | 0.8.4 | Generates OpenMapTiles vector tiles into PMTiles from OSM PBF | [onthegomap/planetiler](https://github.com/onthegomap/planetiler) |
| **GDAL** | 3.8+ | Merging, cropping, warping, and sentinel nodata filling of DEM GeoTIFFs | `gdal-bin`, `libgdal-dev` |
| **Python** | 3.10+ | Orchestration and pipeline glue scripts | Standard Python |
| **rasterio** | >= 1.3.9 | Geospatial raster I/O for Python | `pip install rasterio` |
| **rio-rgbify** | >= 1.1.0 | Encodes raw DEM elevation into Mapbox Terrain-RGB raster tiles | `pip install rio-rgbify` |
| **go-pmtiles** (`pmtiles`) | >= 1.20.0 | Packaging raster directory/mbtiles to PMTiles v3 | [protomaps/go-pmtiles](https://github.com/protomaps/go-pmtiles) |
| **rclone** | >= 1.66.0 | Fast, robust S3/R2 upload with caching and checksums | `rclone` binary |
| **PyYAML** | >= 6.0 | Parsing `regions.yaml` configuration | `pip install pyyaml` |
| **requests** | >= 2.31.0 | Downloading source extracts and verifying HTTP endpoints | `pip install requests` |

## Pipeline Structure

```
tools/map-pipeline/
├── regions.yaml              # V1 region definitions (bounds, sources, overlap)
├── requirements.txt          # Python dependencies
├── README.md                 # Pipeline documentation and tool specs
├── download_osm.py           # Download Geofabrik OSM PBF extracts
├── generate_vector_tiles.py  # Planetiler OpenMapTiles -> map.pmtiles (z0-14)
├── download_dem.py           # Copernicus GLO-30 tile downloader
├── process_dem.py            # GDAL merge, crop, nodata fill
├── encode_terrain_rgb.py     # Terrain-RGB encoding & PMTiles packaging (z0-12)
├── generate_fallback.py      # Low-zoom (z0-6) global fallback PMTiles
├── generate_catalog.py       # Computes SHA-256, generates catalog.json
├── validate_catalog.py       # Verifies catalog.json schema and files
├── upload_r2.sh              # Uploads catalog & PMTiles to Cloudflare R2
├── run_pipeline.py           # End-to-end local/CI runner
└── test_pipeline.py          # Automated test suite for validation
```

## Coordinate System and Terrain-RGB Specification

- Coordinate Reference System: WGS 84 (EPSG:4326) / Web Mercator (EPSG:3857)
- Elevation encoding formula (meters):
  $$\text{elevation} = -10000 + ((R \times 65536 + G \times 256 + B) \times 0.1)$$
- Decoding formula:
  $$\text{value} = \text{round}((\text{elevation} + 10000) / 0.1)$$
  $$R = \lfloor\text{value} / 65536\rfloor \pmod{256}$$
  $$G = \lfloor\text{value} / 256\rfloor \pmod{256}$$
  $$B = \text{value} \pmod{256}$$
- Missing DEM / Water sentinel:
  $\text{elevation} = 0\text{ m} \implies \text{value} = 100000 \implies R=1, G=134, B=160$.

## Overlap Margins

To ensure seamless paragliding cross-country (XC) flight computer display and elevation queries across region borders, every region has an applied overlap margin of 20 km (~0.18° latitude, ~0.26° longitude at 46°N).

## Running the Pipeline Locally

1. Install Python dependencies:
   ```bash
   pip install -r tools/map-pipeline/requirements.txt
   ```
2. Run end-to-end test or single region build:
   ```bash
   python3 tools/map-pipeline/run_pipeline.py --region alps-east --workdir /tmp/brandyfly-maps
   ```
3. Validate catalog:
   ```bash
   python3 tools/map-pipeline/validate_catalog.py --catalog /tmp/brandyfly-maps/output/catalog.json
   ```
