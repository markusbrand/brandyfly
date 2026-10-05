## 1. Governance and provider constants

- [x] 1.1 Update the KK7 entry in `docs/data_source_governance.md` (CC BY-NC-SA 4.0, `src` parameter, on-device fetch without redistribution, privacy note on tile coordinates, revalidation date, note to contact the author about prefetch load). Verify with `tools/validate-data-sources.sh`
- [x] 1.2 Add a single KK7 provider constants file (base URL, layer name pattern, `src=brandyfly`, native max zoom 12, TMS flag, attribution text). Verify a unit test asserts the URL generated for `thermals_jul_07` z10/545/664 including the TMS y flip

## 2. Variant selection domain logic

- [x] 2.1 Add `ThermalSeason` and `ThermalTimeOfDay` enums (incl. `auto`) with KK7 code mapping. Verify unit tests cover all 5 x 5 combinations producing the correct `thermals_<season>_<time>` id
- [x] 2.2 Implement the pure-Dart NOAA sunrise calculation. Verify unit tests against reference sunrise times (e.g. Innsbruck 21 Jun and 21 Dec, ±2 min) and that polar day/night return "no sunrise"
- [x] 2.3 Implement `ThermalVariantResolver` (month→season bin, hours-since-sunrise→time bin with 6 h / 9 h thresholds, before-sunrise→morning, polar→`all`, position fallback chain). Verify unit tests for every scenario in `kk7-thermal-heatmap-layer` "Automatic season selection" and "Automatic time-of-day selection"

## 3. Settings model and configuration UI

- [x] 3.1 Add `mapThermalSeason`, `mapThermalTimeOfDay` and `mapThermalOpacity` to the map widget config in `ui_config.dart`, with effective defaults (`auto`, `auto`, 0.6) and serialization. Verify a round-trip test, and that legacy configs without the fields load with defaults
- [x] 3.2 Add the global `thermalAutoPrefetch` setting (default true) to the persisted `UIConfig`. Verify with a persistence test
- [x] 3.3 Extend `widget_config_sheet.dart` under "Thermal Updraft Hotspots" with season, time-of-day and opacity (10-100%, 10% steps) controls, shown only when the toggle is on. Verify a widget test changes each value and persists it

## 4. Thermal tile serving

- [x] 4.1 Add a `RegionBoundsProvider` reading bounds from `regions/<id>/map.pmtiles` headers (catalog bounds hook stubbed for later). Verify a unit test with a fixture archive
- [x] 4.2 Add a persistent thermal browse cache under `{appSupport}/thermal_cache/` with atomic writes, zero-byte empty markers and a 200 MB LRU cap. Verify unit tests for hit/miss, empty marker and eviction
- [x] 4.3 Add the `/thermals/<variant>/{z}/{x}/{y}.png` route to `LocalTileServer`. Lookup order: region store, then browse cache, then KK7 (5 s timeout, TMS flip, `src`, no identifying headers), then transparent PNG. Verify with tests using an injected `HttpClient`: offline-with-region, offline-without-tiles (transparent, 200), online-fills-cache, timeout→transparent, and request URL/headers contain no identifiers

## 5. Map rendering

- [x] 5.1 Remove `defaultMockThermalHotspots`, `_paintThermals` and related paints from `map_widget.dart`. Update tests asserting mock thermal dots. Verify `flutter test test/map_widget_integration_test.dart` passes and no mock thermal markers are drawn
- [x] 5.2 Inject the thermal raster source (256 px, maxZoom 12) and layer (opacity from config) into the style below the first label layer in `MapLibreMapService.buildStyleJson`, only when `mapShowThermals` is on (web: direct KK7 TMS URL). Verify a unit test on the generated style JSON for on/off, opacity and layer position
- [x] 5.3 Re-evaluate the variant every 60 s and on position jumps over 50 km in the map widget state, and swap the source and layer via `StyleController` without a style reload. Verify a widget test with a fake clock showing the morning→midday switch within 60 s, camera unchanged
- [x] 5.4 Show "Thermal map © thermal.kk7.ch, CC BY-NC-SA 4.0" in the map attribution while the layer is visible. Verify a widget test asserts presence when on and absence when off

## 6. Thermal prefetch

- [x] 6.1 Implement the pure prefetch planner (required variants incl. last-month lookahead, z0-12 XYZ tile enumeration for a bbox). Verify unit tests: July → 4 `jul` variants, 10 Aug → `jul`+`oct`, tile count for a known bbox matches the reference calculation
- [x] 6.2 Implement `ThermalPrefetchService` storage and state (`regions/<id>/thermals/<variant>/...`, `state.json`, skip-existing, atomic writes). Verify a unit test where a resumed run after interruption ends with the same tile set as an uninterrupted run
- [x] 6.3 Add the rate limiter (≤4 req/s, ≤2 concurrent) and backoff on 429/5xx/timeout with `partial` status. Verify unit tests with a fake clock and fake HTTP client assert request timing, concurrency and partial-state marking
- [x] 6.4 Prune non-required variants only after all required variants are complete. Verify a unit test where old variants survive a failed refresh and are deleted after a successful one
- [x] 6.5 Wire the triggers (app start/resume, new region detected, required-variant change, manual retry), respecting `thermalAutoPrefetch`. Verify unit tests for each trigger and for opt-out suppressing automatic runs only
- [x] 6.6 Add a "Thermal map data" panel in map settings listing local regions with state, percentage, size, seasons and a refresh/retry action. Verify a widget test renders each state and that retry calls the service

## 7. Integration and validation

- [x] 7.1 Run `flutter analyze` and `flutter test` in `apps/mobile` and verify both pass with no new warnings
- [x] 7.2 Run a performance check: with the heatmap visible the existing telemetry/UI performance tests (`test/perf`, `telemetry_latency_and_perf_test.dart`) stay within their thresholds, and `test/perf/thermal_prefetch_load_test.dart` shows a 50 Hz telemetry timer stays on time (p95 < 16 ms) while prefetch runs at 250x the production rate
- [x] 7.3 Manual device check (Android): download or place a region, let prefetch complete, enable airplane mode, and verify the heatmap renders offline for all four time variants of the current season. Record evidence in the PR
- [x] 7.4 Run `npx openspec validate --all --strict` and verify it passes
- [x] 7.5 Make MapLibre Android request tiles from the loopback server while the device has no connectivity (`MapLibre.setConnected(true)` in `MainActivity`). Verify on the emulator that the heatmap renders in airplane mode

## Verification evidence

- Automated: `flutter analyze` clean; `flutter test` 454 passed (1 pre-existing skip); `cargo fmt --check`, `cargo clippy -p brandyfly_contracts`, `cargo test` and `tools/validate-data-sources.sh` pass; `openspec validate --all --strict` passes.
- Live KK7 check (2026-10-05): 52/52 real tiles prefetched for a small Krippenstein bbox and served offline through the loopback server. KK7 answers empty tiles with HTTP 200 and a 68-byte image; real tiles average about 6 KB.
- Android emulator (`brandyfly_test_device`, API 34, `-gpu host -no-snapshot`), 2026-10-06: a header-only test region (13.45-13.95 E, 47.35-47.70 N) was prefetched automatically on app start (292/292 tiles, 4 `oct_*` variants, 1.6 MB, about 4 requests/s). With the browse cache deleted and airplane mode on, the heatmap rendered from the region store for the morning, midday, evening and all-day variants at zoom 11; the browse cache stayed empty. Labels rendered correctly.
- Performance: a 50 Hz timer stayed within 2 ms while prefetch ran at 250x the production rate.

## Open limitations

- MapLibre Android pauses all tile requests while Android reports no connectivity. This also affected the existing offline base map and terrain; task 7.5 fixes it for the whole app. Not yet checked on a physical device or on iOS.
- The KK7 author was informed about the expected load on 2026-10-05; no reply yet. Request rate, zoom limit and prefetched variants are single constants if changes are requested.
- Map labels render incorrectly in the emulator's software GPU mode (`swiftshader_indirect`); use `-gpu host -no-snapshot` (see `docs/development.md`).
- No region download manager exists yet; regions currently have to be placed under `regions/<id>/map.pmtiles`.
