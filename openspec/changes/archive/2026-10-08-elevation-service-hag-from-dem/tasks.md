## Tasks

### Dart PMTiles reader
- [x] Implement PMTiles v3 header parser (version, tile type, compression, bounds, center, min/max zoom, directory offsets)
- [x] Implement root and leaf directory entry parsing for tile offset/length lookup
- [x] Implement tile retrieval by (z, x, y) coordinate with seek-based RandomAccessFile reads
- [x] Handle gzip and brotli tile decompression
- [x] Add unit tests with a small fixture PMTiles file containing known terrain-RGB tiles

### ElevationService core
- [x] Implement Web Mercator coordinate-to-tile projection (lat, lon to z=12 tile x, y and pixel px, py)
- [x] Implement PNG raster tile decoding to raw RGBA pixel buffer
- [x] Implement terrain-RGB elevation decoding: `elevation = -10000 + ((R * 65536 + G * 256 + B) * 0.1)`
- [x] Implement bilinear interpolation between 4 nearest pixels for sub-pixel coordinates
- [x] Implement LRU cache (8 tiles) for decoded pixel buffers
- [x] Implement `getElevation(lat, lon)` with terrain source lookup, tile load, decode, and cache
- [x] Implement `getElevationProfile()` batch query for terrain profiles
- [x] Implement `addTerrainSource()` and `removeTerrainSource()` for dynamic region registration

### HAG integration
- [x] Wire ElevationService into the flight telemetry pipeline (call getElevation on each GPS update)
- [x] Compute HAG as barometric altitude minus ground elevation
- [x] Feed HAG value into the existing `hag` widget type
- [x] Handle null elevation gracefully (display "---" when outside downloaded regions)
- [x] Hold previous HAG value during cache miss async resolution to avoid flickering

### Testing
- [x] Unit test PMTiles reader against fixture archive with known tile contents
- [x] Unit test terrain-RGB decoding against known elevation values
- [x] Unit test bilinear interpolation accuracy
- [x] Unit test LRU cache behavior (eviction, hit rates)
- [x] Unit test ElevationService with mock PMTiles (known coordinates to known elevations)
- [x] Integration test HAG widget displaying computed values
