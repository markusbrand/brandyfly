## Context

See `proposal.md` for motivation and issue summaries.

The BrandyFly architecture decouples real-time high-priority sensor loops from UI and disk serialization. However, serialization routines (`IGCParserService`), UI session state (`ScreenManagerService`), and offline tile bundling (`generate_fallback.py`, `build_overview_pmtiles.py`) execute on background threads and user interface controllers. The fixes in this design address edge cases in numeric encoding, state machine transitions, and binary PMTiles directory offsets without impacting hot sensor loops.

## Goals / Non-Goals

**Goals:**
- Guarantee state persistence invariants in `ScreenManagerService.removeScreen` so active screens and widget selections remain stable.
- Ensure strict compliance with the FAI IGC standard for sub-sea-level altitude formatting in `generateIgc`.
- Support seamless UTC midnight crossing in `parseIgc` without negative durations or broken telemetry derivative math.
- Conform `tools/map-pipeline` and `tools/map_pipeline` PMTiles v3 directory offset encoding to the official specification, eliminating infinite loops during deduplication and wrong offsets for non-contiguous archives.

**Non-Goals:**
- Modifying the underlying `UIConfig` data model or breaking backwards compatibility with saved screen JSON.
- Altering the Dart `PMTilesReader` directory decoding logic (it already implements spec-compliant decoding).
- Rearchitecting the flight tracking state machine beyond timestamp continuity.

## Decisions

### Decision 1: Screen Removal Invariant Protection
- **Approach**: In `ScreenManagerService.removeScreen(String screenId)`:
  1. Check if `_config.screens` contains a screen with `id == screenId`. If not found, immediately return (no-op).
  2. Filter `updatedScreens = _config.screens.where((s) => s.id != screenId).toList()`.
  3. Determine `nextActive`:
     - If `_config.activeScreenId == screenId`, the active screen was deleted; clear `_selectedWidgetId = null` and select `updatedScreens.first.id`.
     - If `_config.activeScreenId != screenId`, retain `_config.activeScreenId` without modifying `_selectedWidgetId`.
- **Alternatives Considered**:
  - *Keep previous index*: Selecting the adjacent screen index when active screen is deleted. *Trade-off*: Adds index bounds tracking complexity; `updatedScreens.first.id` is acceptable when deleting the active screen, but keeping active screen when deleting an *inactive* screen is the crucial requirement.

### Decision 2: Signed Altitude Padding for IGC Generation
- **Approach**: Implement `_formatIgcAltitude(int altitude)`:
  ```dart
  static String _formatIgcAltitude(int altitude) {
    final clamped = altitude.clamp(-9999, 99999);
    if (clamped < 0) {
      return '-${clamped.abs().toString().padLeft(4, '0')}';
    }
    return clamped.toString().padLeft(5, '0');
  }
  ```
- **Rationale**: FAI IGC Specification Section 4.1 requires a fixed width of 5 characters for pressure and GNSS altitude fields in B-records. Negative altitudes below sea level are represented as a leading `-` followed by 4 digits (e.g. `-0050` for -50m).
- **Alternatives Considered**:
  - *Using 5 digits of absolute value without minus sign*: Loses sub-sea-level distinction.
  - *Offsets by 1000m*: Violates FAI IGC specification and fails verification on XContest.

### Decision 3: UTC Midnight Rollover in IGC Parsing
- **Approach**: In `IGCParserService.parseIgc`:
  Maintain `currentDate` initialized to `flightDate ?? DateTime.now()`.
  Track `lastSecondsOfDay` from the B-record's `HHMMSS`. If `secondsOfDay < lastSecondsOfDay - 43200` (detecting a 12+ hour step backward, indicating rollover past 23:59:59 to 00:00:00), add 1 day (`const Duration(days: 1)`) to `currentDate`.
  Pass `currentDate` to `_parseBRecord`.
- **Rationale**: IGC files do not store full dates in B-records, only `HHMMSS`. The header `HFDTE` specifies the flight start date. Detecting time step backward guarantees that timestamps monotonically increase across midnight.
- **Alternatives Considered**:
  - *Two-pass post-processing*: Iterate through points afterwards and fix dates. *Trade-off*: Slower and allocates additional intermediate lists. Inline tracking is $O(N)$ with zero extra allocations.

### Decision 4: Spec-Compliant PMTiles v3 Directory Offset Encoding
- **Approach**: In `create_directory` across `tools/map-pipeline/generate_fallback.py` and `tools/map_pipeline/build_overview_pmtiles.py`:
  Implement the official PMTiles v3 specification section A.1:
  ```python
  next_byte = 0
  for i, (_, _, length, offset) in enumerate(entries):
      if i > 0 and offset == next_byte:
          out.extend(encode_varint(0))
      else:
          out.extend(encode_varint(offset + 1))
      next_byte = offset + length
  ```
- **Rationale**:
  - Official PMTiles v3 specification states: "Offsets are encoded either as `Offset + 1` or `0`, if they are equal to the sum of offset and length of the previous entry".
  - The previous code wrote `offset - last_offset + 1`. This was a flawed interpretation of delta encoding. If `offset < last_offset` (tile deduplication), `offset - last_offset + 1 < 0`, causing Python's `n >>= 7` on negative numbers to infinite loop (`-1 >> 7 == -1`). If `offset > last_offset` (non-contiguous tiles), the decoded offset was shifted by `last_offset` instead of being absolute.
- **Alternatives Considered**:
  - *Clamping to 0*: Does not solve the offset corruption on standard PMTiles v3 readers. Conforming directly to the specification ensures interoperability with MapLibre Native, PMTiles CLI, and BrandyFly's reader.

## Risks / Trade-offs

- **[Risk] Long flights spanning multiple days**: The rollover detection checks for a single or multiple midnight rollovers. Paragliding flights rarely exceed 12-14 hours, but even on multi-day continuous bivouac recordings, day increments will reliably trigger each time `secondsOfDay` resets.
  - *Mitigation*: Threshold `secondsOfDay < lastSecondsOfDay - 43200` reliably separates forward recording intervals from midnight resets.
- **[Risk] Pre-existing invalid IGC logs in disk cache**: Users who previously saved flights with negative altitudes might have invalid `00-50` strings.
  - *Mitigation*: `IGCParserService.parseDetailedBRecord` can optionally sanitize `line.substring(25, 30)` if it matches `00-\d+` by parsing `-` correctly during import.
- **[Performance & Latency Trade-offs]**:
  - Zero memory overhead added to the hot sensor pipeline.
  - All changes have $O(1)$ or $O(N)$ complexity with no additional heap allocations in critical flight paths.
