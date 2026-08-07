## Why

BrandyFly needs a reproducible, agent-friendly foundation before hardware and
mapping spikes can begin. Establishing module boundaries and validation now
prevents latency-sensitive flight code, UI code, backend operations, and data
pipelines from becoming coupled accidentally.

## What Changes

- Create a public MIT-licensed monorepo for the Flutter app, Rust flight core,
  native platform plugin, Go backend, and map tooling.
- Configure the expanded OpenSpec workflow for GitHub Copilot and Copilot cloud
  agents.
- Add minimal buildable/testable module skeletons with explicit contracts.
- Add GitHub Actions checks for every implemented language and OpenSpec.
- Add a hardened ARM64-capable backend container baseline.
- Document local development, licensing, security reporting, and contribution
  expectations.

Non-goals:

- Implement sensor acquisition, sensor fusion, maps, flight recording, or
  network product features.
- Claim SkyDrop compatibility.
- Deploy production infrastructure or publish store builds.

## Capabilities

### New Capabilities

- `repository-foundation`: Defines the source layout, module boundaries, public
  licensing, and supported developer workflow.
- `continuous-validation`: Defines automated validation for specifications,
  source modules, generated artifacts, and production container builds.

### Modified Capabilities

None.

## Impact

This creates the initial repository and all top-level development surfaces.
Dependencies are limited to foundation tooling and empty module runtimes. Future
changes will consume these boundaries rather than creating parallel project
layouts.
