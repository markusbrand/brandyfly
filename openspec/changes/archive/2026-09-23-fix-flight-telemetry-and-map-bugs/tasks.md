## 1. Screen Manager Invariant Hardening

- [x] 1.1 Update `ScreenManagerService.removeScreen` in `apps/mobile/lib/services/screen_manager_service.dart` to ignore non-existent screen IDs and only update `activeScreenId` and `_selectedWidgetId` when the active screen itself is removed.
- [x] 1.2 Add unit test in `apps/mobile/test/screen_manager_test.dart` asserting that removing an inactive screen or non-existent ID preserves the active screen and selected widget, and verify with `flutter test test/screen_manager_test.dart`.

## 2. IGC Sub-Sea-Level Altitude and Midnight UTC Fixes

- [x] 2.1 Implement signed 5-character altitude formatting in `IGCParserService.generateIgc` (`apps/mobile/lib/services/igc_parser_service.dart`) to properly serialize negative altitudes (e.g. `-0050`).
- [x] 2.2 Update `IGCParserService.parseIgc` to detect time steps backward indicating UTC midnight rollover, incrementing `currentDate` by 1 day and ensuring positive flight durations and dynamic vario/speed/heading calculations.
- [x] 2.3 Add unit tests in `apps/mobile/test/services/igc_parser_service_test.dart` (or `test/flight_tracking_test.dart`) validating negative altitude round-trip and midnight rollover parsing, verifying with `flutter test`.

## 3. Map Pipeline PMTiles v3 Offset Encoding Compliance

- [x] 3.1 Update `create_directory` in `tools/map-pipeline/generate_fallback.py` to conform to PMTiles v3 specification section A.1 (`write_varint(0)` when contiguous, `write_varint(offset + 1)` when non-contiguous).
- [x] 3.2 Update `create_directory` in `tools/map_pipeline/build_overview_pmtiles.py` to match the PMTiles v3 specification.
- [x] 3.3 Add regression unit tests for PMTiles directory offset encoding and deduplication in `tools/map-pipeline/test_pipeline.py` and verify execution with `python3 -m unittest tools/map-pipeline/test_pipeline.py`.

## 4. End-to-End Verification

- [x] 4.1 Run full test suite in `apps/mobile` via `flutter test` and static analysis via `flutter analyze`.
- [x] 4.2 Run OpenSpec change validation with `openspec validate --all --strict`.
