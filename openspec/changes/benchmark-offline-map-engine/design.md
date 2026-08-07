## Context

See `proposal.md` for motivation. The app has no production map dependency yet.
The decision is between the modern `maplibre` Flutter package and
`maplibre_gl`. Performance on Web or Linux is not evidence for native mobile,
and an online style would invalidate the local-first requirement.

## Goals / Non-Goals

**Goals:**

- Compare candidates with identical data, style, camera script, and overlays.
- Capture native mobile frame, memory, startup, and failure evidence.
- Keep the benchmark repeatable as map dependencies evolve.
- Produce a clear selection or a blocked result.

**Non-Goals:**

- Optimise the final cartographic style.
- Benchmark the full future Alpine download catalogue.
- Treat emulator, simulator, desktop, or Web results as release gates.

## Decisions

### Use one checked benchmark scenario

A small Alpine fixture, style, scripted camera path, and generated overlay stream
will be versioned together. Both engine adapters receive the same semantic
operations and report results in one JSON schema.

Alternative: separate sample apps from each package. Rejected because differing
styles and workloads would make results incomparable.

### Measure release builds on physical devices

Android and iOS release/profile builds will run for at least 10 minutes after a
documented thermal stabilisation step. Native frame metrics, process memory,
first-map timing, and pipeline heartbeat delays are collected.

Alternative: rely on Flutter DevTools in debug mode. Rejected because debug
overhead and map platform views do not represent production frame pacing.

### Assert offline behaviour at the network boundary

The benchmark runs with network access disabled and uses only local style
resources and PMTiles. Missing or corrupt fixtures must result in an explicit
error, never transparent online fallback.

Alternative: inspect logs for tile URLs. Rejected because hidden SDK requests or
cached online data could still produce a false pass.

### Select only against mandatory gates

The decision record separates mandatory offline/correctness/performance gates
from qualitative API and maintenance considerations. Qualitative advantages
break ties only after both candidates pass.

Alternative: weighted scoring that can compensate for a failed mandatory gate.
Rejected because ergonomics must not outweigh in-flight reliability.

## Risks / Trade-offs

- [A small fixture understates regional memory pressure] -> Include dense
  contours and overlays, record size, and require a later full-region package
  test before release.
- [Package versions improve after the spike] -> Pin tested versions and preserve
  the harness for deliberate re-evaluation.
- [iOS and Android expose different renderer metrics] -> Normalise only common
  measures and retain platform-specific raw evidence.
- [The 60 FPS gate is unattainable on a reference device] -> Record a blocked
  decision and optimise or evaluate another approach; do not lower the gate
  without a separate requirement change.

## Migration Plan

1. Add fixture provenance and checksum before map code.
2. Implement a thin benchmark adapter for each candidate.
3. Run CI smoke tests with synthetic data and physical-device gate runs manually.
4. Record the selected dependency and remove the rejected adapter from app code.
5. If neither passes, keep both out of production and retain the harness for the
   next experiment.
