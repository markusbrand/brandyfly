## Why

BrandyFly's latency and durability targets depend on the boundary between native
sensor acquisition, the Rust flight core, native audio, persistent recording,
and Flutter snapshots. That boundary must be measured on both platforms before
the production flight core is designed around it.

## What Changes

- Define a versioned synthetic sensor-event and trace format with monotonic
  timestamps and quality metadata.
- Prototype Android and iOS native acquisition feeding a Rust core through a
  narrow FFI boundary and bounded queues.
- Prototype low-latency native audio control, rate-limited Flutter KPI snapshots,
  and crash-safe append-only writes.
- Measure latency, queue pressure, data loss, lifecycle interruptions, and energy
  impact with deterministic replay.
- Record ownership, threading, backpressure, and failure decisions for the
  production implementation.

Non-goals:

- Implement production Kalman filtering or flight KPIs.
- Produce final vario tones or certified IGC output.
- Add SkyDrop-specific protocol parsing.
- Claim six-hour battery compliance from a short technical benchmark.

## Capabilities

### New Capabilities

- `native-flight-pipeline-validation`: Defines the observable contracts and
  evidence required for BrandyFly's native-to-Rust real-time flight pipeline.

### Modified Capabilities

None.

## Impact

The change affects the Rust core, Kotlin and Swift plugin implementations,
synthetic replay fixtures, benchmark tooling, and architecture documentation.
Synthetic inputs are used in CI; real captures must be anonymised. Flutter must
not become the timing authority or unbounded consumer of sensor events.
