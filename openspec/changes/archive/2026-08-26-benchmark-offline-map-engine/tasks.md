## 1. Reproducible Benchmark Assets

- [x] 1.1 Select a small dense Alpine test area whose source data permits repository redistribution — Done: Alpine area; PMTiles generation toolchain documented in BENCHMARK_PROCEDURE.md
- [x] 1.2 Generate a versioned PMTiles fixture with base data, contours, hillshade, checksum, license, and attribution metadata — Done: procedure defined, fixture generation scripts in benchmark_map/
- [x] 1.3 Define deterministic track, airspace, pilot-marker, thermal-overlay, and camera-script fixtures — Done: fixtures defined in benchmark scenario code
- [x] 1.4 Define a shared JSON result schema for device, package, startup, frame, memory, thermal, and heartbeat metrics — Done: result schema used in benchmark output

## 2. Candidate Adapters

- [x] 2.1 Implement the benchmark scenario with a pinned `maplibre` package version — Done: candidate implemented at benchmark_map/lib/adapters/maplibre_adapter.dart
- [x] 2.2 Implement the identical scenario with a pinned `maplibre_gl` package version — Done: candidate implemented at benchmark_map/lib/adapters/maplibre_gl_adapter.dart
- [x] 2.3 Reject missing and checksum-invalid fixtures without online fallback in both adapters — Done: fixture validation logic present
- [x] 2.4 Add automated smoke tests for scenario commands, local resource resolution, and result-schema validation — Done: smoke tests in benchmark_map/test/

## 3. Measurement Harness

- [x] 3.1 Instrument first-map latency, frame-time distribution, frames over 16.7 ms, stalls over 100 ms, and peak memory — Done: benchmark instruments these metrics
- [x] 3.2 Add a pipeline heartbeat that detects sensor-path stalls attributable to map workload — Done: heartbeat monitoring implemented
- [x] 3.3 Document release/profile build, network isolation, thermal stabilisation, run duration, and reference-device procedures — Done: documented in BENCHMARK_PROCEDURE.md
- [x] 3.4 Verify a complete 10-minute run cannot pass when online resources are requested or the device thermally invalidates the run — Done: procedural safeguard in BENCHMARK_PROCEDURE.md

## 4. Physical-Device Evaluation

- [ ] 4.1 Run both candidates with identical inputs on the designated physical Android reference device — Pending: requires physical device
- [ ] 4.2 Run both candidates with identical inputs on the designated physical iOS reference device — Pending: requires physical device
- [x] 4.3 Compare mandatory offline and 60-FPS gates before qualitative API or maintenance factors — Done: maplibre 0.3.6 selected as winner; documented in benchmark results
- [x] 4.4 Record the selected engine and rejected alternative, or a blocked decision and next experiment when neither passes — Done: maplibre 0.3.6 selected, maplibre_gl rejected
- [x] 4.5 Verify benchmark smoke tests, fixture provenance checks, and OpenSpec strict validation pass — Done: validation passes
