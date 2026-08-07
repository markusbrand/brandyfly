## Context

See `proposal.md` for motivation. The repository currently has a native Flutter
plugin boundary but no SkyDrop transport implementation or permitted protocol
corpus. Android 10+ can expose Bluetooth Classic RFCOMM APIs; iOS support cannot
be inferred from Android behaviour. Validation needs physical hardware and
monotonic timing, while CI needs a safe deterministic fixture.

## Goals / Non-Goals

**Goals:**

- Separate transport bytes, protocol parsing, and normalised sensor events.
- Produce reproducible evidence for Android latency and reconnect behaviour.
- Make unsupported and unknown platform states explicit.
- Keep captured evidence safe to publish in an MIT repository.

**Non-Goals:**

- Harden the prototype for unattended flight use.
- Tune sensor fusion or implement source failover.
- Emulate successful iOS support when the transport is unavailable.

## Decisions

### Use a transport/parser split

The Android proof of concept will expose raw framed bytes through a small
transport interface and feed a platform-independent parser contract. This makes
recorded payloads replayable without Bluetooth hardware and prevents connection
state from being embedded in field decoding.

Alternative: parse directly inside the Bluetooth callback. Rejected because it
makes deterministic replay and parser fuzzing harder and couples latency
measurement to Android code.

### Timestamp at native receipt

The adapter will capture a monotonic timestamp before buffering or parsing.
Subsequent stages append their own timestamps to one trace identifier. Wall-clock
time remains metadata only.

Alternative: timestamp in Dart or Rust only. Rejected because scheduling and FFI
delay would be indistinguishable from transport delay.

### Keep capture tools explicit and sanitising

Raw capture is disabled by default and writes to app-private storage. A separate
sanitisation step creates the small fixture, strips identifiers and coordinates,
adds expected parse results, and records provenance and redistribution approval.

Alternative: commit a complete real flight capture. Rejected for privacy,
repository size, and uncertain redistribution rights.

### Treat platform support as a gate

Android and iOS receive independent evidence records. iOS is marked unsupported
when only an unauthorised or platform-inaccessible Bluetooth Classic path exists;
the later product must use internal sensors rather than a hidden no-data adapter.

Alternative: keep iOS status open until production implementation. Rejected
because it would let roadmap and UI promises depend on an unverified path.

## Risks / Trade-offs

- [A single device/firmware combination is not representative] -> Record firmware,
  Android version, device model, and repeat the matrix when more hardware exists.
- [Bluetooth scheduling can distort latency] -> Run a 30-minute test with map-like
  load and preserve stage timestamps and thermal state.
- [Protocol evidence cannot be published] -> Publish conclusions and synthetic
  fixtures only; retain restricted evidence outside the repository.
- [Reconnect behaviour differs in flight] -> Keep production support gated on a
  later field test even after this technical gate passes.

## Migration Plan

1. Add the parser contract and replay fixture without enabling runtime discovery.
2. Add the Android-only proof-of-concept transport behind a developer flag.
3. Run hardware tests and publish the evidence report.
4. Remove experimental runtime entry points if the gate fails; fixtures and
   decision records remain useful.
5. A later production change may adopt the validated parser and transport
   contracts but must not silently inherit prototype status.
