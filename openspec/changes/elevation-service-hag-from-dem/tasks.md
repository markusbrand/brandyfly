## Tasks

### Dart PMTiles reader
- [ ] Implement PMTiles v3 header parser (version, tile type, compression, bounds, center, min/max zoom, directory offsets)
- [ ] Implement root and leaf directory entry parsing for tile offset/length lookup
- [ ] Implement tile retrieval by (z, x, y) coordinate with seek-based RandomAccessFile reads
- [ ] Handle gzip and brotli tile decompression
- [ ] Add unit tests with a small fixture PMTiles file containing known terrain-RGB tiles

### ElevationService core
- [ ] Implement Web Mercator coordinate-to-tile projection (lat, lon to z=12 tile x, y and pixel px, py)
- [ ] Implement PNG raster tile decoding to raw RGBA pixel buffer
- [ ] Implement terrain-RGB elevation decoding: `elevation = -10000 + ((R * 65536 + G * 256 + B) * 0.1)`
- [ ] Implement bilinear interpolation between 4 nearest pixels for sub-pixel coordinates
- [ ] Implement LRU cache (8 tiles) for decoded pixel buffers
- [ ] Implement `getElevation(lat, lon)` with terrain source lookup, tile load, decode, and cache
- [ ] Implement `getElevationProfile()` batch query for terrain profiles
- [ ] Implement `addTerrainSource()` and `removeTerrainSource()` for dynamic region registration

### HAG integration
- [ ] Wire ElevationService into the flight telemetry pipeline (call getElevation on each GPS update)
- [ ] Compute HAG as barometric altitude minus ground elevation
- [ ] Feed HAG value into the existing `hag` widget type
- [ ] Handle null elevation gracefully (display "---" when outside downloaded regions)
- [ ] Hold previous HAG value during cache miss async resolution to avoid flickering

### Testing
- [ ] Unit test PMTiles reader against fixture archive with known tile contents
- [ ] Unit test terrain-RGB decoding against known elevation values
- [ ] Unit test bilinear interpolation accuracy
- [ ] Unit test LRU cache behavior (eviction, hit rates)
- [ ] Unit test ElevationService with mock PMTiles (known coordinates to known elevations)
- [ ] Integration test HAG widget displaying computed values
