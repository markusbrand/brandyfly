# Proposal

## Why

Testing a release APK (`flutter build apk --release`) on a physical Android tablet (`KFQUWI`) revealed two critical failures that leave the pilot without any map background:
1. **Android release R8 obfuscation crashes the MapLibre platform view**: `maplibre_android` dynamically proxies `io.flutter.plugin.platform.PlatformView` via JNI (`PortProxyBuilder` / `Class.forName`). Because Android release minification (R8) renames `io.flutter.plugin.platform.PlatformView` and strips its interface methods, creating the map view throws `java.lang.NullPointerException` on `MethodChannel#flutter/platform_views`, leaving the map area completely black for both online and offline tiles.
2. **Offline region downloads silently fake success with a 499-byte stub**: `RegionManagerService` targets `https://cdn.brandyfly.org/...` (which is `NXDOMAIN` because no Cloudflare R2 bucket/domain is configured and the CI pipeline OOMed in Planetiler `--storage=ram`), catches the `SocketException`, and silently runs `_fallbackDownloadFromBundle()`—writing a 499-byte zoom-0 stub (`global_overview.pmtiles`) as `map.pmtiles` and `terrain.pmtiles` in ~200 ms while reporting `"Region downloaded successfully"` and `160.0 MB` used.

## What Changes

- **Android R8 / ProGuard keep rules for MapLibre JNI & PlatformView**: Add `apps/mobile/android/app/proguard-rules.pro` and wire it into `apps/mobile/android/app/build.gradle.kts` to preserve `io.flutter.plugin.platform.**`, `io.flutter.embedding.engine.plugins.**`, `io.flutter.plugin.common.**`, and `com.github.josxha.maplibre.**` in release builds so the native MapLibre GL surface mounts reliably.
- **Remove silent 499-byte stub download fallback**: Remove `_fallbackDownloadFromBundle()` from `RegionManagerService.downloadRegion()`. Surface real network/HTTP errors (`DownloadStatus.failed` with descriptive `errorMessage`) instead of writing synthetic stub files and claiming completion.
- **Validate regional PMTiles integrity & self-heal poisoned stub directories**: Reject regional `map.pmtiles` files that are missing a valid PMTiles v3 magic header or are smaller than 4 KB (such as previously written 499-byte stubs) in both `RegionManagerService.getDownloadedRegions()` and `MapLibreMapService.buildStyleJson()`, so devices with previously faked downloads automatically fall back to online/overview tiles and allow re-downloading.
- **Publish and serve regional PMTiles via GitHub Releases (`maps-v1`)**:
  - Fix Planetiler memory exhaustion in `tools/map-pipeline/generate_vector_tiles.py` by using `--storage=mmap` instead of `--storage=ram` so multi-region builds succeed within CI and workstation RAM limits.
  - Update `tools/map-pipeline/generate_catalog.py`, `tools/map-pipeline/regions.yaml`, and `.github/workflows/map-pipeline.yml` to support flat GitHub Releases asset URLs (`https://github.com/markusbrand/brandyfly/releases/download/maps-v1/<regionId>-map.pmtiles` and `<regionId>-terrain.pmtiles`) and publish `catalog.json` + `.pmtiles` assets directly to the `maps-v1` GitHub Release using `GITHUB_TOKEN` (while keeping Cloudflare R2 upload as an optional secondary target when R2 secrets are present).
  - Update `RegionManagerService.defaultCatalogUrl` and `apps/mobile/assets/map_data/catalog.json` to point to the `maps-v1` GitHub Release assets.

## Non-Goals

- Changing the visual design of the Alpine Relief style or adding new vector map layers.
- Requiring external paid CDN or Cloudflare R2 credentials for offline region downloads to work.
- Modifying the KK7 thermal tile prefetch pipeline or airspace parser.

## Capabilities

### New Capabilities

*(None)*

### Modified Capabilities

- `offline-vector-map-rendering`: Require Android release builds (R8/ProGuard) to preserve JNI-accessed Flutter `PlatformView` and MapLibre classes so the native MapLibre canvas renders in release APKs, and prevent synthetic stub files from being mounted as primary regional archives.
- `offline-region-management`: Prohibit silent fallback to bundled stub archives on network failure during region downloads, require PMTiles v3 header/size validation and self-healing of invalid stub directories, and use the GitHub Releases catalog endpoint by default.
- `offline-map-region-pipeline`: Use disk-backed mmap storage in Planetiler vector tile generation to prevent OOM failures, support flat GitHub Release asset naming (`<regionId>-map.pmtiles`, `<regionId>-terrain.pmtiles`), and publish generated region archives and `catalog.json` to GitHub Releases.

## Impact

- **Mobile App (Android / Flutter)**:
  - `apps/mobile/android/app/build.gradle.kts` & `apps/mobile/android/app/proguard-rules.pro`
  - `apps/mobile/lib/services/region_manager_service.dart`
  - `apps/mobile/lib/services/maplibre_map_service.dart`
  - `apps/mobile/assets/map_data/catalog.json`
  - Unit & widget tests in `apps/mobile/test/services/region_manager_service_test.dart` and `apps/mobile/test/services/maplibre_map_service_test.dart`
- **Map Pipeline & CI**:
  - `tools/map-pipeline/regions.yaml`
  - `tools/map-pipeline/generate_vector_tiles.py`
  - `tools/map-pipeline/generate_catalog.py`
  - `tools/map-pipeline/publish_github_release.sh` & `.github/workflows/map-pipeline.yml`
- **Privacy, Safety, Offline & Licensing**:
  - **Safety & Offline**: Pilots will no longer be misled by a false `"Downloaded (160.0 MB)"` status backed by a 499-byte stub when preparing for offline flights, and release APKs on physical Android devices will render the map background and terrain hillshade reliably.
  - **Privacy**: Region downloads remain anonymous HTTPS GET requests to GitHub Releases / CDN with no user tracking or telemetry.
  - **Licensing**: Preserves ODbL (OpenStreetMap), CC BY 4.0 (Copernicus GLO-30 DEM), and public domain (Natural Earth) attributions in `catalog.json`.
