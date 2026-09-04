---
id: SPEC-NATIVE-FLIGHT-PIPELINE
type: sub-spec
parent: EPIC-01-CORE
title: Native Flight Pipeline Validation
issue_number: 19
status: closed
labels:
  - spec
  - openspec
---

# native-flight-pipeline-validation Specification

## Purpose

Defines timing, backpressure, lifecycle, and durability evidence for the
native-to-Rust flight-data path before production flight features depend on it.

## Requirements

### Requirement: Sensor events carry end-to-end timing metadata
Every benchmark sensor event SHALL carry a version, source identifier, source
timestamp when available, native monotonic receive timestamp, sequence number,
and quality flags through the Rust boundary.

#### Scenario: Event reaches the core
- **WHEN** a native adapter submits a valid event
- **THEN** the core trace preserves its timing and quality metadata without using wall-clock time for latency calculation

#### Scenario: Event is malformed
- **WHEN** an event violates the versioned contract
- **THEN** it is rejected with a counted reason and is not converted into a valid-looking sample

### Requirement: Latency targets are independently verified
The pipeline benchmark SHALL measure p50, p95, and maximum latency from native
receipt to Rust processing, native audio reaction, and visible Flutter KPI on
representative Android and iOS devices.

#### Scenario: Real-time gates pass
- **WHEN** a reference-device run completes under the documented sensor and map load
- **THEN** receive-to-core p95 is at most 50 ms, receive-to-audio p95 is at most 80 ms, and receive-to-visible-KPI p95 is at most 100 ms

#### Scenario: A gate fails
- **WHEN** any p95 threshold is exceeded
- **THEN** the corresponding platform gate remains failed and the trace identifies the affected stage

### Requirement: Backpressure is bounded and observable
Every asynchronous pipeline boundary SHALL have a documented finite capacity,
overflow policy, and counters for dropped, replaced, stale, and rejected events.

#### Scenario: Flutter consumer is stalled
- **WHEN** the Flutter consumer stops reading KPI snapshots while sensor input continues
- **THEN** native acquisition, Rust processing, and audio continue without unbounded memory growth and overflow counters expose any discarded snapshots

#### Scenario: Input exceeds capacity
- **WHEN** event production exceeds a queue's configured capacity
- **THEN** the documented overflow policy is applied deterministically and counted

### Requirement: Lifecycle interruptions produce explicit outcomes
The benchmark SHALL exercise foreground, background, audio interruption, and
process-termination paths allowed by each target platform and record which
pipeline stages continue, pause, resume, or terminate.

#### Scenario: Supported background transition
- **WHEN** the app enters an allowed background flight state
- **THEN** acquisition and recording continue or the trace records an explicit platform denial without silent data fabrication

#### Scenario: Process terminates during append
- **WHEN** the benchmark process is terminated during a record write
- **THEN** restart recovery returns all complete records, rejects any incomplete tail, and reports the discarded byte count

### Requirement: Replay results are deterministic
The same versioned synthetic replay SHALL produce identical ordered core outputs,
overflow decisions, and persistence results for repeated runs using the same
configuration.

#### Scenario: Repeated replay
- **WHEN** the replay suite runs the fixture at least three times
- **THEN** all normalised outputs and counters match the committed expectations
