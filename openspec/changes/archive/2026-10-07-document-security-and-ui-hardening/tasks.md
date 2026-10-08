## 1. Map Pipeline Security Validation

- [x] 1.1 Verify `download_osm.py` rejects non-Geofabrik URLs and terminates with security error
- [x] 1.2 Verify `LocalTileServer` does not emit wildcard CORS headers via test in `test/services/local_tile_server_test.dart`

## 2. UI Instrument Resilience Validation

- [x] 2.1 Verify `VarioLiftSinkBar` renders vertical edge bar style in tiny tier allocations
- [x] 2.2 Run mobile instrument widget tests ensuring all tiny and compact size tiers render without overflow

## 3. Specification Coherence & Verification

- [x] 3.1 Validate all OpenSpec specs and delta requirements with `npx openspec validate --all --strict`
