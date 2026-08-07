## Why

BrandyFly currently depends on real sensors and live integrations for meaningful
end-to-end validation, which slows development and hides regressions until field
tests. A deterministic local testing mode is needed now so contributors can
verify full app behavior safely on a laptop without live flight inputs.

## What Changes

- Add a development-only local mock flight mode that runs the complete app flow
  using synthetic flight telemetry and mocked external interfaces.
- Provide deterministic scenario replay so runs are reproducible across machines
  and CI.
- Define explicit behavior for offline, stale-data, and upstream-failure cases
  in mock mode, including visible state transitions and error reporting.
- Add guardrails that prevent mock mode and its fixtures from being enabled in
  production builds.
- Document privacy/safety boundaries so synthetic runs never use private pilot
  data or present mock data as live flight authority.

Non-goals:

- Replacing real-device and in-flight validation for release sign-off.
- Simulating every vendor-specific edge case in the first iteration.
- Shipping mock controls or debug fixtures in production distributions.

## Capabilities

### New Capabilities

- `local-mock-flight-mode`: Defines deterministic, development-only end-to-end
  testing with synthetic flight simulation and mocked external dependencies.

### Modified Capabilities

None.

## Impact

Impacts Flutter UI state wiring, Rust/core input orchestration, native adapter
abstractions, external interface clients, developer tooling, and CI smoke
coverage. Introduces versioned synthetic fixtures and replay seeds, plus build
gating checks to keep mock mode out of production artifacts.
