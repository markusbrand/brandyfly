## Why

During codebase exploration and telemetry stress testing, four reproducible bugs were discovered across flight telemetry serialization, cockpit screen management, and offline vector map packaging:
1. In `ScreenManagerService`, removing any inactive screen or non-existent screen resets the active flight screen to the first screen, causing disruptive navigation changes during flight and clearing widget selection.
2. In `IGCParserService`, exporting negative altitudes (sub-sea-level flying) produces invalid IGC numeric formatting (`00-50`), causing round-trip altitude parsing to fail and reset to 0.0.
3. In `IGCParserService`, parsing flights that cross 00:00:00 UTC assigns the initial day timestamp to post-midnight fixes, resulting in negative flight durations and skipped dynamic telemetry calculations (vario, speed, heading).
4. In `tools/map-pipeline/generate_fallback.py` and `tools/map_pipeline/build_overview_pmtiles.py`, PMTiles directory offset encoding applies relative delta encoding instead of the official PMTiles v3 absolute offset specification, causing corrupted tile reads on non-contiguous archives and infinite loops during tile deduplication.

Resolving these issues ensures in-flight cockpit stability, standards-compliant IGC flight logging and replay, and robust offline vector map generation.

## What Changes

- **Fix Screen Removal Selection Logic**: In `ScreenManagerService.removeScreen`, only update `activeScreenId` if the active screen itself was removed. Ignore removal requests for non-existent screen IDs, and preserve active widget selection unless the active screen is deleted.
- **Fix Negative Altitude Formatting in IGC Generation**: In `IGCParserService.generateIgc`, format negative altitudes with a leading minus sign (e.g. `-0050`) rather than standard `padLeft(5, '0')` which produces `"00-50"`.
- **Fix Midnight UTC Rollover in IGC Parsing**: In `IGCParserService.parseIgc`, detect time wraparound (from `23:59:xx` to `00:00:xx`) and increment the active tracking date by 1 day so flight duration and inter-point `dtSec` calculations remain monotonically positive.
- **Align PMTiles Directory Offset Encoding with v3 Specification**: In `generate_fallback.py` and `build_overview_pmtiles.py`, replace delta offset encoding (`offset - last_offset + 1`) with PMTiles v3 specification rule: `0` if contiguous with previous entry (`offset == prev_offset + prev_len`), otherwise absolute `offset + 1`. This prevents negative inputs to `encode_varint` during deduplication and fixes tile index offsets for non-contiguous archives.

### Non-Goals

- Refactoring the entire `ScreenManagerService` architecture or adding new UI themes.
- Adding full multi-day flight logging beyond standard midnight crossing.
- Rewriting the Python map pipeline in Rust or Dart.

## Capabilities

### Modified Capabilities

- `screen-widget-configuration`: Preserve active screen and widget selection invariants when removing non-active screens or invalid screen IDs.
- `flight-tracking-logbook-and-replay`: Ensure valid IGC export for sub-sea-level altitudes and robust parsing of flights crossing midnight UTC without negative durations.
- `offline-map-region-pipeline`: Ensure PMTiles v3 directory offset encoding adheres strictly to specification for non-contiguous tiles and deduplication.

## Impact

- **Affected Code**:
  - `apps/mobile/lib/services/screen_manager_service.dart`
  - `apps/mobile/lib/services/igc_parser_service.dart`
  - `tools/map-pipeline/generate_fallback.py`
  - `tools/map_pipeline/build_overview_pmtiles.py`
  - Relevant test suites in `apps/mobile/test/` and pipeline tests
- **Safety Impact**: Prevents inadvertent cockpit screen jumps during flight maneuvers when background or edit operations occur.
- **Offline Impact**: Preserves offline map generation and archive validity without hanging fallback generator scripts.
- **Privacy & Licensing**: No changes to privacy or licensing; all fixes adhere to existing MIT licensing.
