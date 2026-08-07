## 1. Reproducible Benchmark Assets

- [ ] 1.1 Select a small dense Alpine test area whose source data permits repository redistribution
- [ ] 1.2 Generate a versioned PMTiles fixture with base data, contours, hillshade, checksum, license, and attribution metadata
- [ ] 1.3 Define deterministic track, airspace, pilot-marker, thermal-overlay, and camera-script fixtures
- [ ] 1.4 Define a shared JSON result schema for device, package, startup, frame, memory, thermal, and heartbeat metrics

## 2. Candidate Adapters

- [ ] 2.1 Implement the benchmark scenario with a pinned `maplibre` package version
- [ ] 2.2 Implement the identical scenario with a pinned `maplibre_gl` package version
- [ ] 2.3 Reject missing and checksum-invalid fixtures without online fallback in both adapters
- [ ] 2.4 Add automated smoke tests for scenario commands, local resource resolution, and result-schema validation

## 3. Measurement Harness

- [ ] 3.1 Instrument first-map latency, frame-time distribution, frames over 16.7 ms, stalls over 100 ms, and peak memory
- [ ] 3.2 Add a pipeline heartbeat that detects sensor-path stalls attributable to map workload
- [ ] 3.3 Document release/profile build, network isolation, thermal stabilisation, run duration, and reference-device procedures
- [ ] 3.4 Verify a complete 10-minute run cannot pass when online resources are requested or the device thermally invalidates the run

## 4. Physical-Device Evaluation

- [ ] 4.1 Run both candidates with identical inputs on the designated physical Android reference device
- [ ] 4.2 Run both candidates with identical inputs on the designated physical iOS reference device
- [ ] 4.3 Compare mandatory offline and 60-FPS gates before qualitative API or maintenance factors
- [ ] 4.4 Record the selected engine and rejected alternative, or a blocked decision and next experiment when neither passes
- [ ] 4.5 Verify benchmark smoke tests, fixture provenance checks, and OpenSpec strict validation pass
