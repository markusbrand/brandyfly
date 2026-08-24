# BrandyFly

BrandyFly is a local-first, open-source paragliding vario application for
Android and iOS. The project is in its foundation phase and does not yet provide
flight-ready functionality.

## Architecture

- `apps/mobile`: adaptive Flutter application
- `crates/flight_core`: deterministic Rust flight core
- `plugins/brandyfly_native`: Android/iOS platform boundary
- `services/backend`: lightweight Raspberry Pi backend
- `tools/map_pipeline`: reproducible offline-map tooling
- `packages/contracts`: versioned cross-module contracts
- `openspec`: requirements and change proposals

See [Architecture](docs/architecture.md) and
[Development](docs/development.md) for details.

## OpenSpec workflow

Non-trivial changes start with the repository-local OpenSpec skills configured for Antigravity:

- `openspec-explore`: Enter explore mode to think through ideas or investigate issues.
- `openspec-propose`: Propose a new change and generate planning artifacts.
- `openspec-apply-change`: Guide the implementation of a change.
- `openspec-verify-change`: Run verification and gather evidence.
- `openspec-archive-change`: Archive a completed change and update main specs.

## Safety

BrandyFly is not yet suitable for navigation or flight safety decisions.
Airspace and map data can be incomplete or outdated. Pilots remain responsible
for using current official information and appropriate certified equipment.

## License

Source code is available under the [MIT License](LICENSE). Map, airspace,
elevation, weather, and flight datasets retain their own licenses and
attribution requirements; see [Third-party data](THIRD_PARTY_DATA.md).
