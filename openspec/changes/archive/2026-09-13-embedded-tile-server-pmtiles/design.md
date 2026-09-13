## Context

See `proposal.md` for background and motivation.
Currently, `MapLibreMapService` generates style JSON pointing to `pmtiles://` file paths. On Android, MapLibre Native's C++ core and Java HTTP wrapper (`Mbgl-HttpRequest`) do not recognize the `pmtiles://` scheme and fail to parse file paths as URLs. Because MapLibre Native on both Android and iOS natively supports standard HTTP vector tile URLs, an embedded loopback tile server running on `127.0.0.1` bridges local PMTiles storage directly into MapLibre without modifying the native mobile engines.

## Goals / Non-Goals

**Goals:**
- Provide sub-millisecond local vector tile delivery from `.pmtiles` archives to MapLibre on Android and iOS.
- Maintain zero network egress during flight when regional PMTiles are installed.
- Provide smooth online vector tile fallback during development and simulation testing when regional PMTiles are absent.
- Ensure clean lifecycle management (start on app bootstrap, graceful shutdown on app exit).

**Non-Goals:**
- Raster DEM tile decoding for 3D hillshade in the initial vector bridge (elevation HAG query decoding is handled separately under `elevation-service-hag-from-dem`).
- Full PMTiles writer/editor (pure read-only archive reader).

## Decisions

### 1. Loopback HTTP Server vs. Native Plugin Custom FileSource
- **Decision**: Implement `LocalTileServer` using standard Dart `HttpServer` bound to `InternetAddress.loopbackIPv4` on an ephemeral port (`port = 0`).
- **Rationale**: `HttpServer` in `dart:io` is lightweight, cross-platform (Android, iOS, macOS, Linux), and requires no JNI/Kotlin or Objective-C/Swift native plugin bindings. MapLibre Native already uses optimized HTTP connection pooling via OkHttp on Android and NSURLSession on iOS.
- **Alternatives Considered**:
  - *Native C++ FileSource*: Would require forking or patching `maplibre_android` and compiling custom C++ binaries for all ABI architectures (arm64-v8a, armeabi-v7a, x86_64), adding severe maintenance burden.
  - *Shelf HTTP package*: Unnecessary dependency overhead; standard `dart:io` `HttpServer` handles loopback streaming with negligible latency.

### 2. Pure Dart Seek-Based PMTiles v3 Reader
- **Decision**: Implement `PMTilesReader` using `RandomAccessFile` with seek-based binary reading and an LRU cache for directory entries.
- **Rationale**: Memory efficiency. Regional PMTiles files are 100MB–200MB. Loading the entire archive into memory is prohibitive on mobile devices. `RandomAccessFile.setPositionSync` and `readSync` allow reading only the requested tile bytes (~15KB–50KB per tile).
- **Latency & Battery**: Tile reads take < 1ms on flash storage. Serving from loopback socket adds < 0.5ms. The CPU overhead is negligible, ensuring no impact on 60 FPS flight map panning.
- **Alternatives Considered**:
  - *Memory-mapping (mmap)*: Dart FFI mmap adds platform complexity and memory address space pressure on 32-bit devices. Seek-based reading is safe and fast.

### 3. Source URL in MapLibre Style Specification
- **Decision**: Replace `source.url` with direct `tiles: ["http://127.0.0.1:{port}/tiles/{z}/{x}/{y}.pbf"]` in the compiled style JSON.
- **Rationale**: Eliminates TileJSON round-trip network hop and directly instructs MapLibre to fetch vector tiles from the loopback server.

### 4. Development & Overview Fallback
- **Decision**: When a requested coordinate is outside the loaded local PMTiles archive (or during mock flight simulation where no regional data is downloaded), `LocalTileServer` checks an upstream open vector tile provider (such as OpenFreeMap OpenMapTiles schema) or returns a clean 204 No Content / empty MVT layer.
- **Rationale**: Enables developers and testers to immediately see OpenStreetMap rendered on the simulator without requiring manual ADB pushing of multi-hundred-megabyte regional files.

## Risks / Trade-offs

- **[Risk] Ephemeral Port Collisions or Rebind Delays** → *Mitigation*: Bind to port `0` so the OS kernel assigns an available port, and update style JSON dynamically with the resolved port.
- **[Risk] Multiple Concurrent Tile Requests Stalling Main Thread** → *Mitigation*: Disk I/O in `LocalTileServer` runs asynchronously via `dart:io` worker threads, keeping the Flutter UI thread free.
- **[Risk] Gzip Decompression Overhead** → *Mitigation*: PMTiles tiles are already gzip-compressed; the server streams the compressed bytes directly to MapLibre with `Content-Encoding: gzip` so no re-compression is required.
