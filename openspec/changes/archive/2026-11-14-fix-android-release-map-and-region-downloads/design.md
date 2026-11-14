# Design

## Context

See `proposal.md` for motivation and root-cause analysis from live tablet diagnostics (`KFQUWI`, Android 11 / SDK 30, `arm64-v8a`).

Two independent defects prevented the map background from appearing on the physical tablet:

1. **Android Release R8 Obfuscation of JNI-Bridged `PlatformView` (`NullPointerException`)**:
   - `maplibre_android` (`0.3.6`) registers `MapLibreMapFactory` (`PlatformViewFactory`) on the Flutter engine. When `MapWidget` mounts, `MapLibreMapStateAndroid.buildPlatformWidget` sets `MapLibreRegistry.INSTANCE.flutterApi = jni.FlutterApi.implement(const FlutterApi())` via `package:jni`.
   - When Flutter's `PlatformViewsController.createPlatformView` invokes `MapLibreMapFactory.create(context, viewId, args)`, the Dart `FlutterApi.createPlatformView` calls `jni.PlatformView.implement(...)`, which uses `com.github.dart_lang.jni.PortProxyBuilder` in Java to construct a dynamic `java.lang.reflect.Proxy` for `Class.forName("io.flutter.plugin.platform.PlatformView")`.
   - In debug builds, R8 is disabled, so `io.flutter.plugin.platform.PlatformView` retains its binary name and methods (`getView()`, `dispose()`, etc.).
   - In release builds (`flutter build apk --release`), R8 minification/shrinking is active by default. Because no Java class in the APK statically implements `io.flutter.plugin.platform.PlatformView` (only the dynamic JNI `PortProxyBuilder` does at runtime via string lookup), R8 renames `io.flutter.plugin.platform.PlatformView` to `io.flutter.plugin.platform.f` and removes its methods.
   - `PortProxyBuilder.build()` fails in `Class.forName("io.flutter.plugin.platform.PlatformView")`, returning `null` across JNI and causing `PlatformViewsController.createPlatformView` to throw `java.lang.NullPointerException` on `MethodChannel#flutter/platform_views`.

2. **Offline Region Download Fake Stub Fallback & Missing CDN Hosting**:
   - `RegionManagerService.downloadRegion()` catches any `SocketException` or `ClientException` when connecting to `https://cdn.brandyfly.org/...` (which is `NXDOMAIN`) and calls `_fallbackDownloadFromBundle()`.
   - `_fallbackDownloadFromBundle()` loads `assets/map_data/global_overview.pmtiles` (499 bytes containing a single zoom-0 water tile), sleeps `5 * 20ms`, writes those 499 bytes to `map.pmtiles` and `terrain.pmtiles`, and writes `meta.json` with `sizeBytes: totalExpectedBytes` (e.g., 160 MB).
   - Meanwhile, the automated `.github/workflows/map-pipeline.yml` workflow failed in CI because `generate_vector_tiles.py` invoked Planetiler with `-Xmx4g --storage=ram`, exhausting heap memory during `stage osm` on larger Geofabrik extracts, and had no Cloudflare R2 secrets configured.

## Goals / Non-Goals

**Goals:**
- Ensure `flutter build apk --release` renders the native MapLibre GL map (both online fallback and offline PMTiles) on physical Android devices without JNI / R8 exceptions.
- Eliminate the fake 499-byte stub fallback in `RegionManagerService` and automatically clean up any previously written 499-byte regional stubs on disk.
- Host real generated `.pmtiles` archives and `catalog.json` on GitHub Releases (`maps-v1`) so offline region downloads in Settings work out-of-the-box without external paid CDN infrastructure.
- Fix Planetiler memory usage (`--storage=mmap`) in `tools/map-pipeline/generate_vector_tiles.py` so region builds succeed on both `bosgame` and GitHub Actions runners.

**Non-Goals:**
- Modifying the MapLibre style layers (`alpine_relief.json`) or changing flight instrument widgets.
- Replacing the PMTiles v3 reader or local loopback HTTP server architecture.

## Decisions

### Decision 1: Add Explicit Android ProGuard/R8 Keep Rules for `maplibre_android` and `jni`
- **Choice**: Create `apps/mobile/android/app/proguard-rules.pro` and reference it in `apps/mobile/android/app/build.gradle.kts` under `buildTypes.release`. Keep:
  - `-keep interface io.flutter.plugin.platform.** { *; }`
  - `-keep class io.flutter.plugin.platform.** { *; }`
  - `-keep class io.flutter.embedding.engine.plugins.** { *; }`
  - `-keep interface io.flutter.plugin.common.** { *; }`
  - `-keep class com.github.josxha.maplibre.** { *; }`
  - `-keep class com.github.dart_lang.jni.** { *; }`
  - `-keep class com.github.dart_lang.jni_flutter.** { *; }`
  - `-keep class org.maplibre.** { *; }`
- **Alternatives Considered**:
  - *Disabling R8 completely (`isMinifyEnabled = false`, `isShrinkResources = false`)*: Increases APK size unnecessarily when targeted `-keep` rules for JNI-reflected interfaces solve the exact issue cleanly while preserving R8 optimization for the rest of the app.

### Decision 2: Remove `_fallbackDownloadFromBundle()` and Enforce Minimum Regional PMTiles Validation
- **Choice**:
  1. Delete `_fallbackDownloadFromBundle()` from `RegionManagerService`. When an HTTP request fails (DNS, socket timeout, or non-200/206 status), let the exception propagate to the download error handler so `RegionDownloadProgress` emits `DownloadStatus.failed` with the error description.
  2. Define `static const int minValidRegionArchiveBytes = 4096` (4 KB). Any real regional `map.pmtiles` or `terrain.pmtiles` archive (even a small region) is tens of megabytes, whereas the synthetic `global_overview.pmtiles` stub is 499 bytes (and unit test mock valid PMTiles files can be validated via header + size check or configurable threshold).
  3. Wait — let's check unit tests in `apps/mobile/test/services/region_manager_service_test.dart` and `maplibre_map_service_test.dart`! In unit tests, test fixtures often construct minimal valid PMTiles archives (e.g., 127–600 bytes) or mock HTTP responses!
  - Let's design the stub detection carefully so unit tests with synthetic PMTiles fixtures continue to work while 499-byte `global_overview.pmtiles` stubs masquerading as multi-megabyte catalog regions are rejected:
    - During `downloadRegion()`, verify that each downloaded file starts with the 7-byte `"PMTiles"` v3 magic header (`0x50 0x4d 0x54 0x69 0x6c 0x65 0x73 0x03`), and if `regionFile.sizeBytes > 0`, verify that `targetFile.length() == regionFile.sizeBytes` (or matches `regionFile.sha256` when `sha256` is non-empty)!
    - In `getDownloadedRegions()` and `MapLibreMapService.buildStyleJson()`, if `meta.json` exists and records `sizeBytes > 1000000` (e.g. > 1 MB expected from catalog) while the actual `map.pmtiles` on disk is `<= 1024` bytes (i.e. a 499-byte stub written by the old `_fallbackDownloadFromBundle`), treat the directory as a corrupted stub, delete it, and exclude it!
    - Also record `actualTotalDiskBytes` in `meta.json` instead of `totalExpectedBytes`.
- **Rationale**: This accurately detects and purges any poisoned 499-byte stub directory created by the old bug on devices in the field (including the user's tablet), enforces exact size + header + SHA-256 verification on new downloads, and preserves compatibility with small synthetic PMTiles test fixtures in unit tests.

### Decision 3: Distribute Regional PMTiles and `catalog.json` via GitHub Releases (`maps-v1`)
- **Choice**:
  - Use a dedicated GitHub Release tag `maps-v1` in `markusbrand/brandyfly` (`https://github.com/markusbrand/brandyfly/releases/download/maps-v1`).
  - Because GitHub Release assets use flat filenames, name each region's assets `<regionId>-map.pmtiles` and `<regionId>-terrain.pmtiles` (e.g., `alps-east-map.pmtiles`, `alps-east-terrain.pmtiles`), alongside `overview.pmtiles`, `catalog.json`, and `checksums.sha256`.
  - Update `tools/map-pipeline/generate_catalog.py` so that when `cdn_base_url` is a GitHub Releases URL (or `--flat-urls` is passed), it emits `{cdn_base_url}/{region_id}-map.pmtiles` and `{cdn_base_url}/{region_id}-terrain.pmtiles`.
  - Add `tools/map-pipeline/publish_github_release.sh` (using `gh release create` / `gh release upload --clobber`) and wire it into `.github/workflows/map-pipeline.yml` (with `permissions: contents: write`).
  - Update `tools/map-pipeline/generate_vector_tiles.py` to pass `--storage=mmap` and `--force` to Planetiler so region generation does not OOM on 4 GB heap limits.
  - During implementation on `bosgame`, run the pipeline to generate real PMTiles archives, publish them to the `maps-v1` GitHub Release on `markusbrand/brandyfly`, update `assets/map_data/catalog.json` with the real sizes and SHA-256 checksums, and verify the end-to-end download and map rendering on the connected `KFQUWI` tablet.
- **Alternatives Considered**:
  - *Cloudflare R2 (`cdn.brandyfly.org`)*: Requires setting up a paid Cloudflare R2 bucket, custom DNS domain, and API tokens. Keep `upload_r2.sh` as an optional step when R2 secrets are present, while making GitHub Releases the zero-config default.
  - *On-device tile-by-tile scraping*: Downloading 25,000+ individual PBF and PNG tiles per region from OpenFreeMap/Terrarium on mobile is slow, battery-intensive, and risks rate-limiting compared to a single range-resumable `.pmtiles` archive.

## Risks / Trade-offs

- **[Risk] GitHub Release asset size limit (2 GB per file)** → Each paragliding region (`alps-east`, `alps-central`, etc.) at zoom 0–14 vector + zoom 0–12 terrain is ~40–180 MB, well under the 2 GB per-asset limit.
- **[Risk] Existing devices with 499-byte stub regions from previous builds** → Mitigated by self-healing check in `getDownloadedRegions()` and `MapLibreMapService.buildStyleJson()` that detects and deletes stub directories where `meta.json` claims >1 MB but `map.pmtiles` is <=1,024 bytes.
- **[Risk] HTTP 302 Redirects on GitHub Release asset downloads** → `package:http`'s `http.Request` follows redirects (`followRedirects = true` by default) while preserving `Range` headers across redirects to `objects.githubusercontent.com`.
