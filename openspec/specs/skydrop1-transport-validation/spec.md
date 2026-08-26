# skydrop1-transport-validation Specification

## Purpose

Defines the evidence, measurements, fixtures, and platform decisions required
before BrandyFly can claim support for SkyDrop 1 as a flight sensor.

## Requirements

### Requirement: Protocol claims are evidence backed
The validation result SHALL identify the transport, framing, message fields,
units, update rates, and connection lifecycle from a manufacturer-authorised or
otherwise permitted source, with the source and verification date recorded.

#### Scenario: Permitted protocol evidence is available
- **WHEN** the protocol report is reviewed
- **THEN** every implemented field and transport claim is traceable to recorded permitted evidence

#### Scenario: A protocol detail remains unverified
- **WHEN** a required field or transport behaviour lacks permitted evidence
- **THEN** the affected support decision is marked blocked and no guessed implementation is accepted

### Requirement: Android transport is validated on real hardware
The validation suite SHALL connect an Android 10 or newer reference device to a
physical SkyDrop 1, receive samples, detect disconnection, and reconnect without
requiring an app process restart.

#### Scenario: Connected sample stream
- **WHEN** the paired SkyDrop 1 emits data during a hardware test
- **THEN** received payloads include a monotonic receive timestamp, sequence information when available, and an explicit parse result

#### Scenario: Link interruption
- **WHEN** the Bluetooth link is interrupted and restored
- **THEN** the trace reports the interruption, stale-data interval, reconnect duration, and first valid post-reconnect sample

### Requirement: Transport latency and integrity are measurable
The validation report SHALL state sample rate, parse failures, duplicates,
sequence gaps, stale samples, and p50, p95, and maximum receive-to-core latency
for a test lasting at least 30 minutes.

#### Scenario: Latency gate passes
- **WHEN** a complete reference-device run reports receive-to-core p95 latency of 50 ms or less with no unexplained sample loss
- **THEN** the Android transport latency gate is marked passed

#### Scenario: Latency or integrity gate fails
- **WHEN** the latency threshold is exceeded or loss cannot be explained
- **THEN** the gate is marked failed with the raw trace retained for diagnosis

### Requirement: Replay evidence is safe and deterministic
The repository SHALL contain a versioned, redistributable fixture with expected
parse results that excludes credentials and precise private flight locations.

#### Scenario: Fixture replay
- **WHEN** the committed fixture is replayed repeatedly on the same code revision
- **THEN** it produces identical ordered parse results and error classifications

#### Scenario: Unsafe capture
- **WHEN** a candidate capture contains credentials, device secrets, or unsanitised private coordinates
- **THEN** it is rejected from repository fixtures

### Requirement: Platform support boundaries are explicit
The validation result SHALL independently classify Android and iOS as supported,
unsupported, or blocked, including the transport and evidence behind each
classification.

#### Scenario: iOS transport is unavailable
- **WHEN** platform restrictions or manufacturer requirements prevent a permitted SkyDrop 1 connection on iOS
- **THEN** the result records iOS as unsupported and requires internal sensors to remain the visible fallback
