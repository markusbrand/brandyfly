# Third-party data

The MIT License applies to BrandyFly source code, not automatically to data
downloaded, transformed, or displayed by the application.

Every data package must include its source, version or retrieval time, license,
required attribution, and redistribution terms. Candidate providers such as
OpenStreetMap, Geofabrik, open flightmaps, OpenAIP, elevation providers, live
tracking services, and XContest require a license and API review before use.

No production dataset is bundled during the repository bootstrap.

## Attribution Notices

### OpenStreetMap
- **Source**: OpenStreetMap contributors
- **License**: Open Database License (ODbL) 1.0
- **Attribution**: © OpenStreetMap contributors
- **URL**: https://www.openstreetmap.org/copyright

### Copernicus DEM GLO-30
- **Source**: European Space Agency (ESA) / Copernicus Programme
- **License**: Creative Commons Attribution 4.0 International (CC-BY-4.0)
- **Attribution**: Contains modified Copernicus DEM data © ESA/Copernicus (2021) distributed under CC BY 4.0
- **URL**: https://sentinels.copernicus.eu/web/sentinel/news/-/article/copernicus-dem-new-release-available

### Natural Earth
- **Source**: Natural Earth contributors / North American Cartographic Information Society (NACIS)
- **License**: Public Domain
- **Attribution**: Made with Natural Earth. Free vector and raster map data @ naturalearthdata.com.
- **URL**: https://www.naturalearthdata.com/about/terms-of-use/

## Offline Map Region Pipeline Data Sources

The automated pipeline in `tools/map-pipeline/` processes source datasets into regional PMTiles archives:

| Pipeline Artifact | Source Data | Transformation Tool | Licensing & Attribution |
|---|---|---|---|
| `map.pmtiles` (zoom 0-14) | Geofabrik OpenStreetMap regional PBF extracts | Planetiler (OpenMapTiles profile) | Open Database License (ODbL) 1.0; © OpenStreetMap contributors |
| `terrain.pmtiles` (zoom 0-12) | Copernicus GLO-30 30m DEM GeoTIFFs (AWS Open Data) | GDAL (crop/merge/fill) + rio-rgbify (Terrain-RGB) + go-pmtiles | Creative Commons Attribution 4.0 (CC-BY-4.0); modified Copernicus DEM data © ESA/Copernicus |
| `overview.pmtiles` (zoom 0-6) | Natural Earth vector outlines | Planetiler / Direct vector packager | Public Domain; Made with Natural Earth |
| `catalog.json` | Pipeline metadata manifest | `tools/map-pipeline/generate_catalog.py` | Embedded machine-readable attribution for OSM, Copernicus, and Natural Earth |

