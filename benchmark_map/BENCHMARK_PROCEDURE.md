# BrandyFly Offline Map Engine Benchmark — Procedure

This document defines the repeatable procedure for running the benchmark on physical Android and iOS
reference devices. A run that deviates from these steps **must not be reported as release evidence**.

---

## Reference Devices

| Platform | Model | OS Version | Notes |
|---|---|---|---|
| Android | `FILL_IN_DEVICE_MODEL` | Android `FILL_IN_VERSION` | Designated reference — do not change |
| iOS | `FILL_IN_DEVICE_MODEL` | iOS `FILL_IN_VERSION` | Designated reference — do not change |

Fill in the device model and OS version before the first run. Record these in the benchmark result JSON.

---

## 1. Prerequisite: PMTiles Fixture Generation

The benchmark app requires two PMTiles files that are **not bundled in the repository** due to
licensing constraints. You must generate them before any device run.

### 1.1 Install the PMTiles generation toolchain

```bash
# Install tippecanoe (for vector tiles) and go-pmtiles
brew install tippecanoe           # macOS
# or: apt install tippecanoe      # Debian/Ubuntu

# Install go-pmtiles CLI
go install github.com/protomaps/go-pmtiles/cmd/pmtiles@latest
```

### 1.2 Generate `alpine_overview.pmtiles` (Vector Tiles — ODbL)

```bash
# Download OSM extract for Austria/Salzkammergut from Geofabrik
wget https://download.geofabrik.de/europe/austria-latest.osm.pbf -O /tmp/austria.osm.pbf

# Convert to MBTiles with tippecanoe (zoom 0-14)
tippecanoe \
  --output=/tmp/alpine_overview.mbtiles \
  --minimum-zoom=0 --maximum-zoom=14 \
  --drop-densest-as-needed \
  --extend-zooms-if-still-dropping \
  --attribution="© OpenStreetMap contributors (ODbL)" \
  /tmp/austria.osm.pbf

# Convert to PMTiles
pmtiles convert /tmp/alpine_overview.mbtiles /tmp/alpine_overview.pmtiles

# Record SHA-256
sha256sum /tmp/alpine_overview.pmtiles
```

Update `fixture_manifest.json` → `fixtures[0].sha256` and `fixtures[0].sizeBytes` with the output.

### 1.3 Generate `alpine_terrain.pmtiles` (Copernicus DEM — CC-BY-4.0)

```bash
# Download Copernicus GLO-30 DEM tiles for the Dachstein area
# See: https://sentinels.copernicus.eu/web/sentinel/news/-/article/copernicus-dem-new-release-available

# Convert terrain-RGB to PMTiles using gdal + rio-cogeo + go-pmtiles
# (Detailed procedure: see Copernicus DEM usage guidelines)

# Record SHA-256
sha256sum /tmp/alpine_terrain.pmtiles
```

Update `fixture_manifest.json` → `fixtures[1].sha256` and `fixtures[1].sizeBytes`.

### 1.4 Push fixtures to the device

**Android:**
```bash
adb push /tmp/alpine_overview.pmtiles \
  /sdcard/Android/data/rocks.brandstaetter.benchmark_map/files/alpine_overview.pmtiles

adb push /tmp/alpine_terrain.pmtiles \
  /sdcard/Android/data/rocks.brandstaetter.benchmark_map/files/alpine_terrain.pmtiles
```

**iOS:** Use Xcode's Device & Simulators window → transfer files into the benchmark app's container,
or use `ios-deploy --bundle_id rocks.brandstaetter.benchmark_map`.

---

## 2. Build Commands

### maplibre adapter (release build)

**Android:**
```bash
cd benchmark_map
flutter build apk --release --dart-define=BENCHMARK_ADAPTER=maplibre
adb install build/app/outputs/flutter-apk/app-release.apk
```

**iOS:**
```bash
cd benchmark_map
flutter build ios --release --dart-define=BENCHMARK_ADAPTER=maplibre
# Deploy via Xcode or ios-deploy
```

### maplibre_gl adapter (release build)

```bash
flutter build apk --release --dart-define=BENCHMARK_ADAPTER=maplibre_gl
flutter build ios --release --dart-define=BENCHMARK_ADAPTER=maplibre_gl
```

> [!IMPORTANT]
> Always use `--release` for device evaluation. Debug builds have significant overhead
> and do not represent production frame pacing.

---

## 3. Network Isolation

Before every valid benchmark run:

1. Enable **Airplane Mode** on the device.
2. Verify connectivity: open a browser and confirm it cannot load any page.
3. The benchmark app displays "No online fallback will be attempted" — confirm this message
   appears before tapping Start.

A run where network requests are possible **is not valid release evidence**.

---

## 4. Thermal Stabilisation

1. Plug the device in to charge (prevents battery saving throttling).
2. Leave the device idle (screen on, brightness at 50%) for **5 minutes**.
3. If the device feels warm to the touch or a thermal throttling indicator appears, wait an additional 5 minutes.
4. Begin the run immediately after stabilisation — do not delay.

A run that begins outside the documented thermal state must be excluded. Set `thermal.invalidated = true` in the result JSON and re-run.

---

## 5. Run Duration

The benchmark scenario runs for **at least 10 minutes** (600 seconds). Each waypoint in
`camera_script.json` is executed at 15-second intervals, giving 40 camera movements over
the full run.

Do not interrupt the device during the run.

---

## 6. Result Collection

After the run completes, the app displays the result on screen and saves a JSON file to the
app's support directory.

**Collect the result file:**

```bash
# Android
adb shell run-as rocks.brandstaetter.benchmark_map ls files/
adb pull \
  /sdcard/Android/data/rocks.brandstaetter.benchmark_map/files/<result_file>.json \
  ./results/

# iOS
# Use Xcode Device window → Download Container → inspect AppData/Documents/
```

Name the result file: `result_{adapter}_{platform}_{date}.json`
(e.g. `result_maplibre_android_2026-08-25.json`)

---

## 7. Mandatory Gates

A candidate **passes** only if **all** of the following are true:

| Gate | Requirement |
|---|---|
| Offline pass | No network requests during the run (airplane mode enforced) |
| p95 frame time | ≤ 16.7 ms (≥ 60 FPS) on both Android and iOS |
| Thermal validity | `thermal.invalidated == false` |
| Run duration | ≥ 10 minutes of camera script execution |
| Fixture checksum | SHA-256 in result matches fixture_manifest.json |

A candidate that fails any mandatory gate is **not selected**, regardless of qualitative API
or maintenance advantages.

---

## 8. Decision Record

After both candidates have been evaluated on both platforms:

1. If exactly one candidate passes all gates → select it, record the rejected alternative's gaps.
2. If no candidate passes → record a blocked decision with the next experiment.
3. Do not select the "least failing" option.

Record the decision in issue #17 (`benchmark-offline-map-engine`) tasks section.

---

## 9. Pre-Run Checklist

Complete this checklist before each run. A run without a completed checklist is not valid:

- [ ] PMTiles fixtures generated and pushed to device
- [ ] `fixture_manifest.json` updated with real SHA-256 checksums
- [ ] Device model and OS version recorded in result JSON
- [ ] Release build installed (not debug)
- [ ] Airplane mode enabled and verified
- [ ] Device charged and plugged in
- [ ] 5-minute thermal stabilisation completed
- [ ] Run lasted ≥ 10 minutes
- [ ] Result JSON collected and named correctly
