## Summary

Build an automated pipeline that generates offline map region packages (vector map PMTiles + terrain-RGB DEM PMTiles) from OpenStreetMap and Copernicus DEM source data, publishes them to a CDN with a versioned catalog, and runs on a monthly schedule to keep region data current.

## Problem Statement

The app-side changes (issues #84, #85, #86) implement MapLibre rendering from local PMTiles and a region download manager, but they require actual PMTiles files and a hosted catalog to download from. Without a data generation pipeline, there are no region packages to serve. The pipeline must transform raw OSM planet extracts and Copernicus DEM GeoTIFFs into compact, correctly formatted PMTiles archives for each curated flying region, and host them on a CDN with a machine-readable catalog.

## Proposed Solution

1. **Region Definition Config**: A YAML/JSON configuration defining each flying region's bounding box, ID, name, description, and overlap margins.
2. **Vector Tile Generation**: Use Planetiler to generate OpenMapTiles-schema vector tiles from Geofabrik OSM PBF regional extracts, output as PMTiles per region.
3. **Terrain DEM Generation**: Process Copernicus GLO-30 GeoTIFF tiles into terrain-RGB encoded raster tiles, package as PMTiles per region using rio-tiler/gdal2tiles + pmtiles CLI.
4. **Global Fallback Generation**: Generate a low-zoom (0-6) global overview PMTiles from Natural Earth data for bundling in the app.
5. **Catalog Generation**: Produce a `catalog.json` with all region metadata, file URLs, sizes, SHA-256 checksums, and version timestamps.
6. **CDN Publishing**: Upload region PMTiles and catalog to Cloudflare R2 (or equivalent object storage with free egress) for anonymous HTTPS download.
7. **CI Automation**: GitHub Actions workflow running monthly (or on-demand) to regenerate and republish all regions.

## Goals

- Produce correctly formatted PMTiles archives that render in MapLibre and can be decoded by the Dart PMTiles reader for elevation queries.
- Keep region data current with monthly regeneration from fresh OSM extracts.
- Minimize hosting costs (Cloudflare R2 free egress, ~5 GB total storage).
- Make the pipeline reproducible and auditable (version-pinned tools, checksummed outputs).
- Comply with all data licensing requirements (OSM ODbL, Copernicus CC-BY-4.0, Natural Earth public domain).

## Non-Goals

- On-demand custom region generation (all regions are pre-defined in the catalog).
- Real-time or daily data freshness (monthly is sufficient for OSM base map data).
- Serving tiles via a tile server API (the app downloads complete PMTiles files, not individual tile requests).

## Capabilities

### New Capabilities

- `offline-map-region-pipeline`: Automated generation and CDN publishing of offline map region packages from OSM and Copernicus DEM source data.

### Modified Capabilities

None.

## Impact

- **Infrastructure**: Requires Cloudflare R2 bucket (or equivalent) for hosting (~5 GB storage, free egress, ~0.08 USD/month).
- **CI**: GitHub Actions workflow with ~30-60 minute build time per full pipeline run (Java for Planetiler, GDAL for DEM processing).
- **Data licensing**: Generated tiles carry ODbL (OSM), CC-BY-4.0 (Copernicus DEM), and public domain (Natural Earth) obligations. Attribution metadata is included in catalog and region metadata files.
- **Repository**: Pipeline scripts, region definitions, and CI workflow live in the monorepo under `tools/map-pipeline/` or `services/map-pipeline/`.
