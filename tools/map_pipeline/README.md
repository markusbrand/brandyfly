# Map Pipeline

This directory contains the reproducible map data build pipeline for BrandyFly's
offline-first PMTiles distribution. It covers vector tiles, terrain relief, and
contour lines.

Source extracts and generated PMTiles are intentionally excluded from Git. No
provider is used until the corresponding data-license review is complete.

---

## Region Output Structure

Each region produces three PMTiles archives under `regions/<region-id>/`:

```
regions/
└── alps-austria/
    ├── map.pmtiles        # Vector tiles: roads, landuse, POIs, labels
    ├── terrain.pmtiles    # Raster-DEM tiles: Copernicus 30m elevation (Terrarium)
    └── contours.pmtiles   # Vector contour tiles: 10m intervals (optional)
```

All three files are expected at runtime. `contours.pmtiles` is optional — the app
renders gracefully without it (contour layers are stripped from the style JSON).

---

## Pipeline Steps

### Prerequisites

```bash
pip install gdal-bin rio-rgbify pyogrio
# tippecanoe: https://github.com/felt/tippecanoe
# pmtiles:    https://github.com/protomaps/go-pmtiles
```

### 1. Vector Tiles — `map.pmtiles`

Uses [Planetiler](https://github.com/onthegomap/planetiler) with the OpenMapTiles
profile:

```bash
# Download OSM extract for the region (e.g. Austria from geofabrik)
wget https://download.geofabrik.de/europe/austria-latest.osm.pbf

# Run Planetiler (outputs map.mbtiles)
java -jar planetiler.jar \
  --area=austria \
  --output=map.mbtiles \
  --download

# Convert to PMTiles
pmtiles convert map.mbtiles regions/alps-austria/map.pmtiles
```

### 2. Terrain Relief — `terrain.pmtiles`

Uses [Copernicus DEM GLO-30](https://spacedata.copernicus.eu/explore) via
rio-rgbify to produce Terrarium-encoded raster-DEM tiles:

```bash
# Download and merge Copernicus 30m DEM tiles for the region
gdal_merge.py -o regional-dem.tif cop30m_*.tif

# Encode as Terrarium RGB raster (each RGB pixel encodes an elevation value)
rio rgbify -b -10000 -i 0.1 regional-dem.tif terrain-rgb.tif

# Package into MBTiles (zoom 5–14)
gdal2tiles.py --zoom=5-14 --processes=4 terrain-rgb.tif terrain-tiles/
mbutil terrain-tiles/ terrain.mbtiles

# Convert to PMTiles
pmtiles convert terrain.mbtiles regions/alps-austria/terrain.pmtiles
```

### 3. Contour Lines — `contours.pmtiles`

Derived from the same regional DEM GeoTIFF produced in step 2:

```bash
# Step 3a: Generate contour lines at 10m intervals from the regional DEM
gdal_contour \
  -i 10 \
  -a elevation \
  -f GeoJSON \
  regional-dem.tif \
  contours.geojson

# Step 3b: Package with tippecanoe (zoom 10–14, simplify at lower zooms)
tippecanoe \
  -o contours.mbtiles \
  -z 14 \
  -Z 10 \
  --simplification=10 \
  --drop-densest-as-needed \
  --layer=contours \
  contours.geojson

# Step 3c: Convert to PMTiles
pmtiles convert contours.mbtiles regions/alps-austria/contours.pmtiles
```

**Tippecanoe flags explained:**
- `-z 14 -Z 10`: Serve tiles from zoom 10 to 14 (matches MapLibre layer minzoom settings)
- `--simplification=10`: Simplify geometry at lower zooms to reduce tile size
- `--drop-densest-as-needed`: Gracefully drop lines in dense areas to keep tile size manageable
- `--layer=contours`: Sets the MVT source-layer name (must match `source-layer: contours` in the style JSON)

---

## Updating Regions

To add a new region:
1. Set `REGION_ID` (e.g. `swiss-alps`) and download the corresponding OSM extract and DEM tiles.
2. Run steps 1–3 above, outputting into `regions/<REGION_ID>/`.
3. Deploy the three `.pmtiles` files to the CDN or copy to device app support dir.

The app auto-detects the region by scanning `<appSupportDir>/regions/` for
directories containing `map.pmtiles`.
