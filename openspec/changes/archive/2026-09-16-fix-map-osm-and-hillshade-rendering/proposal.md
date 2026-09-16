## Why

When testing MapLibre map rendering in the emulator or real devices, the map displays an empty canvas populated only by a dense field of brown/white peak dots, with no visible OpenStreetMap landuse, water, roads, trails, aerialways, or terrain hillshade relief.

This occurs because `alpine_relief.json` was defined primarily with Protomaps vector layer names (`roads`, `pois`, `places`, `earth`) and property keys (`kind`, `kind_detail`), whereas both the local Planetiler pipeline and the upstream OpenFreeMap vector tile provider emit standard OpenMapTiles schema v3 (`transportation`, `poi`, `place`, `mountain_peak`, `water`, `landcover`, `landuse` using `class` and `subclass`). The only layer that matched was `peak-omt-points` without any filter, rendering hundreds of unfiltered peak dots. Furthermore, `alpine_relief.json` lacks a `hillshade` layer, and `MapLibreMapService` completely removes terrain DEM sources when running without pre-downloaded regional DEM files.

## What Changes

- **OpenMapTiles v3 Schema Alignment in `alpine_relief.json`**:
  - Re-wire landuse and landcover layers to match OpenMapTiles classes (`forest`, `wood`, `grass`, `meadow`, `scrub`, `bare_rock`, `rock`, `glacier`, `residential`).
  - Wire water polygons and waterway lines to OpenMapTiles `water` and `waterway` layers (`river`, `stream`, `canal`).
  - Map transportation layers to OpenMapTiles `transportation` (`class`: `motorway`, `trunk`, `primary`, `secondary`, `tertiary`, `minor`, `service`, `track`, `path`, and aerialways: `cable_car`, `gondola`, `chair_lift`, `drag_lift`).
  - Filter and style mountain peaks properly: render subtle peak markers and labels with elevation (e.g. at zoom >= 11, ranked) rather than an unfiltered mass of dots at all zooms.
  - Wire place labels to OpenMapTiles `place` (`class`: `city`, `town`, `village`, `hamlet`).
- **Hillshade Relief Integration & Development Fallback**:
  - Add the `hillshade` raster-dem layer beneath vector layers in `alpine_relief.json` with NW 315° illumination.
  - Extend `LocalTileServer` to serve `/terrain/{z}/{x}/{y}.png` from local `terrain.pmtiles` when available, or transparently proxy and disk-cache online AWS Terrarium DEM tiles during simulation/development when regional DEM files are absent.
  - Update `MapLibreMapService` to retain the terrain source and hillshade layer pointing to `LocalTileServer` baseUrl in fallback mode.

### Non-Goals

- Implementing full multi-region batch downloader (managed by `offline-region-download-manager`).
- Custom contour vector lines extraction (Copernicus DEM hillshade raster relief fulfills the visual terrain awareness requirement).

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `offline-vector-map-rendering`: Update Alpine Relief style schema requirements to OpenMapTiles v3 vector layers/attributes and enable loopback proxy and disk-caching for terrain hillshade tiles when local DEM archives are absent.

## Impact

- **Affected Code**:
  - `apps/mobile/assets/map_styles/alpine_relief.json`: Updated layer definitions, filters, and hillshade layer.
  - `apps/mobile/lib/services/local_tile_server.dart`: Terrain tile proxying (`/terrain/{z}/{x}/{y}.png`) and disk caching.
  - `apps/mobile/lib/services/maplibre_map_service.dart`: Terrain source configuration for both local PMTiles and loopback proxy.
  - `apps/mobile/test/services/local_tile_server_test.dart`: Terrain tile proxy unit tests.
  - `apps/mobile/test/services/maplibre_map_service_test.dart`: Updated style compilation tests.
- **Dependencies**: No external dependency changes.
- **Flight Safety & Offline Guarantee**: Offline PMTiles retain 100% priority when present with zero network traffic emitted during flight.
