## Context

See `proposal.md` for motivation. BrandyFly spans Flutter UI, Rust flight
processing, native sensor bridges, and external integrations; end-to-end tests
currently rely on live inputs and are hard to reproduce. The design must keep
flight-critical paths offline-capable and avoid any production risk from
development test controls.

## Goals / Non-Goals

**Goals:**

- Add one dev-only runtime mode that swaps live inputs for deterministic
  synthetic telemetry and interface mocks.
- Keep replay outputs stable across laptops and CI for regression comparison.
- Exercise success, offline, stale-data, and failure paths through the real app
  state machines.
- Enforce privacy and safety boundaries for synthetic data usage.

**Non-Goals:**

- Certifying release readiness without real-device/live-source verification.
- Emulating every third-party provider behavior in the first delivery.
- Supporting mock mode in production binaries or user-facing release settings.

## Decisions

### Central mode switch in shared runtime config

Introduce a single `local_mock_flight_mode` configuration resolved at startup
and propagated to Flutter, Rust core, and native adapters.

Alternative: separate per-module flags. Rejected because partial activation can
mix mock/live data and invalidate deterministic behavior.

### Fixture-driven deterministic event engine

Use versioned scenario fixtures plus explicit seed, clock step, and start epoch
to generate telemetry and external responses in a deterministic sequence.

Alternative: random-on-each-run generators. Rejected because nondeterminism
prevents replay diffs and makes CI flaky.

### Dependency-boundary mock adapters

Implement mock adapters at external interface boundaries (sensors, network APIs,
upload/export endpoints) while keeping business logic and UI flows unchanged.

Alternative: UI-only stubs. Rejected because they bypass cross-layer behavior
and miss integration regressions.

### Explicit stale/failure injection channels

Scenario fixtures include scripted stale timestamps, dropped updates, delayed
responses, and hard errors so state transitions are testable and repeatable.

Alternative: ad-hoc manual toggles. Rejected because they are hard to automate
and cannot guarantee coverage for regression baselines.

### Production exclusion and visible simulation safety cues

Build-time gating strips mock mode from release profiles; runtime also rejects
activation outside dev builds. UI shows persistent simulated-flight indicators.

Alternative: relying only on developer discipline. Rejected due to safety and
trust risk if simulated data appears live in production.

## Risks / Trade-offs

- [Synthetic scenarios diverge from field reality] → Keep required live-flight
  validation for release and periodically refresh fixtures from anonymized
  patterns.
- [Cross-platform timing differences break determinism] → Define a logical clock
  contract and compare canonical event hashes rather than wall-clock timing.
- [Mock abstraction adds maintenance overhead] → Limit mocks to stable interface
  boundaries and share fixture schema across modules.
- [Developers accidentally depend on mock-only behavior] → Require CI runs for
  both mock mode and normal mode, with mock mode gated to dev builds only.

## Migration Plan

1. Define fixture schema, deterministic replay contract, and mock mode config.
2. Add boundary adapters and route mode selection through runtime bootstrap.
3. Implement baseline scenarios (nominal, offline, stale, failure) and replay
   assertions.
4. Add build/runtime gating plus simulated-data UI indicators.
5. Add CI smoke tests for deterministic replay and mode exclusion in production
   profiles; keep rollback path by disabling mock mode flag at startup.
