# Tasks

## 1. Android Release ProGuard / R8 Keep Rules for MapLibre PlatformView

- [x] 1.1 Create `apps/mobile/android/app/proguard-rules.pro` preserving `io.flutter.plugin.platform.**`, `io.flutter.embedding.engine.plugins.**`, `io.flutter.plugin.common.**`, `com.github.josxha.maplibre.**`, `com.github.dart_lang.jni.**`, `com.github.dart_lang.jni_flutter.**`, and `org.maplibre.**`, and wire `proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")` into `apps/mobile/android/app/build.gradle.kts` under `buildTypes.release`.
- [x] 1.2 Build the release APK (`flutter build apk --release`) and verify in `build/app/outputs/mapping/release/mapping.txt` that `io.flutter.plugin.platform.PlatformView` and its interface methods (`getView`, `dispose`) are preserved without renaming or stripping.

## 2. Remove Fake Stub Download Fallback and Add Self-Healing Validation

- [x] 2.1 Remove `_fallbackDownloadFromBundle()` from `apps/mobile/lib/services/region_manager_service.dart` so network, DNS, and HTTP errors during `downloadRegion()` emit `DownloadStatus.failed` with a clear `errorMessage` instead of writing `global_overview.pmtiles` as a fake regional download.
- [x] 2.2 Add PMTiles v3 magic header (`"PMTiles\x03"`) and size verification in `RegionManagerService.downloadRegion()`, record actual verified disk byte size in `meta.json`, and self-heal invalid stub directories (where `meta.json` claims `> 1 MB` or catalog size while `map.pmtiles` on disk is `<= 1024` bytes) in `RegionManagerService.getDownloadedRegions()` and `MapLibreMapService.buildStyleJson()`.
- [x] 2.3 Update and add unit tests in `apps/mobile/test/services/region_manager_service_test.dart` and `apps/mobile/test/services/maplibre_map_service_test.dart` covering failed download error propagation, stub directory cleanup, and valid PMTiles verification, and verify `flutter test test/services/region_manager_service_test.dart test/services/maplibre_map_service_test.dart` passes.

## 3. Map Pipeline Fixes and GitHub Releases (`maps-v1`) Publishing

- [x] 3.1 Update `tools/map-pipeline/generate_vector_tiles.py` to pass `--storage=mmap` and `--force` to Planetiler so vector tile generation does not exhaust JVM heap during `stage osm`.
- [x] 3.2 Update `tools/map-pipeline/generate_catalog.py` and `tools/map-pipeline/regions.yaml` to use `https://github.com/markusbrand/brandyfly/releases/download/maps-v1` and emit flat release asset URLs (`<regionId>-map.pmtiles`, `<regionId>-terrain.pmtiles`, `overview.pmtiles`), and verify `python3 tools/map-pipeline/test_pipeline.py` passes.
- [x] 3.3 Create `tools/map-pipeline/publish_github_release.sh` and update `.github/workflows/map-pipeline.yml` (`permissions: contents: write`) to publish `catalog.json`, `checksums.sha256`, `overview.pmtiles`, and `<regionId>-{map,terrain}.pmtiles` to the `maps-v1` GitHub Release.
- [x] 3.4 Generate the regional PMTiles archives and `catalog.json`, publish them to the `maps-v1` GitHub Release on `markusbrand/brandyfly`, and update `RegionManagerService.defaultCatalogUrl` and `apps/mobile/assets/map_data/catalog.json` with the published URLs, sizes, and SHA-256 checksums.

## 4. End-to-End Tablet Verification

- [x] 4.1 Build and install the updated release APK (`flutter build apk --release`) on the connected `KFQUWI` Android tablet (`GCC1WE0421540ECA` via `garuda`), verify `adb logcat` shows zero `PlatformException` / `NullPointerException` errors, confirm the map background renders, and test downloading an offline region in Settings.
