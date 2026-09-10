## Context

See `proposal.md` for motivation. Flutter, Rust, Kotlin, and Swift modules exist,
but only smoke boundaries are present. The hot path must survive UI stalls and
platform lifecycle changes while remaining measurable from native receipt to
core, audio, visible KPI, and persistent record.

## Goals / Non-Goals

**Goals:**

- Fix ownership and timestamp semantics before production algorithms.
- Prove bounded data movement across native, Rust, audio, storage, and Flutter.
- Make loss, staleness, lifecycle pauses, and recovery observable.
- Use identical deterministic input semantics on Android and iOS.

**Non-Goals:**

- Choose final fusion algorithms or audio profiles.
- Route every raw sample through Flutter.
- Infer a six-hour battery result from a short benchmark.

## Decisions

### Use versioned events and a shared trace identifier

Native adapters create versioned sensor events with monotonic receipt time,
source metadata, sequence, and quality. Rust assigns processing outputs to the
same trace identifier; native audio and Flutter acknowledge their reaction times.

Alternative: platform-specific event objects mapped in Dart. Rejected because it
makes Flutter a hot-path dependency and weakens cross-platform replay.

### Bound every asynchronous boundary

Sensor-to-core uses a finite queue sized from measured source rates. Audio
control keeps the newest applicable value. Flutter receives rate-limited
snapshots and replaces stale pending snapshots. Persistence uses a bounded
append queue and exposes lag.

Alternative: unbounded channels to avoid initial drops. Rejected because a UI or
storage stall could cause memory growth and dangerously stale output.

### Keep audio native and Flutter observational

Rust produces compact control values; native pre-warmed audio generates sound.
Flutter receives lower-rate immutable snapshots for display. Neither map nor
widget work can block sensor processing or audio.

Alternative: generate tones and update KPIs in Dart for simplicity. Rejected
because runtime scheduling and UI contention threaten the latency gates.

### Validate persistence with framed append records

The spike writes length-delimited records with version and checksum to a
temporary append-only file. Recovery scans complete frames, reports and removes
an incomplete tail, and never fabricates the final record.

Alternative: write final IGC text directly. Rejected because this change tests
durability boundaries, not final IGC semantics.

### Separate deterministic CI from device evidence

CI replays synthetic fixtures and verifies outputs, queue policies, and recovery.
Physical Android and iOS runs provide latency, lifecycle, thermal, and energy
evidence in the same result schema.

Alternative: make emulator timing a pass gate. Rejected because host scheduling
cannot establish real-device latency.

## Risks / Trade-offs

- [Cross-language clock domains cannot be compared directly] -> Capture latency
  endpoints within one platform monotonic domain and calibrate only when a
  boundary requires it.
- [Queue policies hide important loss] -> Emit per-reason counters and include
  them in every benchmark result.
- [Background execution differs by platform] -> Report supported platform
  states independently and require visible product fallback later.
- [Instrumentation changes timing] -> Measure tracing overhead and compare
  instrumented with minimally instrumented runs.

## Migration Plan

1. Introduce contracts and synthetic replay without changing app behaviour.
2. Add bounded prototype stages behind a developer-only benchmark entry point.
3. Run CI replay and physical-device acceptance matrices.
4. Preserve accepted contracts and evidence for `implement-flight-core`.
5. Remove prototype UI and audio surfaces; if a gate fails, do not promote that
   platform path to production.
