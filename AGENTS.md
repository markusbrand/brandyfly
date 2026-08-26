# Workspace Guidelines & OpenSpec Workflow

## Project Overview
BrandyFly is an open-source, local-first paragliding vario and flight computer application.
- **Tech Stack**: Flutter/Dart UI (`apps/mobile`), Rust flight core (`crates/`), Kotlin/Swift native platform adapters, MapLibre/PMTiles, Go backend (`services/`).
- **Core Principles**: Safety-critical flight telemetry, offline-first reliability, low latency, deterministic replay support.

---

## Change Management: OpenSpec Workflow

All non-trivial changes, feature additions, bug fixes, and architectural adjustments in this repository MUST follow the **OpenSpec specification-driven change management** workflow using the integrated OpenSpec skills and CLI (`npx openspec` or `openspec`).

### Core Lifecycle

1. **Explore & Ideate (Optional)**:
   - Use the `openspec-explore` skill or `/opsx-explore` when clarifying requirements or investigating problems.

2. **Propose & Plan (Strict Planning Boundary)**:
   - Use `openspec-propose` (or `openspec-new-change` / `/opsx-propose`) to scaffold changes in `openspec/changes/<change-name>/`.
   - Generates: `proposal.md`, delta specifications under `specs/`, `design.md`, and `tasks.md`.
   - **Crucial**: The propose phase authorizes planning only. Do NOT modify source code during this step. Present the artifacts and wait for explicit user confirmation.

3. **Apply & Implement**:
   - Use `openspec-apply-change` (or `/opsx-apply`) to systematically implement tasks defined in `tasks.md`.
   - Follow project standards, keeping sensor/audio loops off the Flutter main thread and preserving offline capabilities.

4. **Verify & Validate**:
   - Use `openspec-verify-change` and run `npx openspec validate --all --strict` to ensure all requirements, scenarios, and tests pass.

5. **Archive & Sync**:
   - Use `openspec-archive-change` (or `/opsx-archive`) to promote delta specs to main `openspec/specs/` and archive the change.
   - Use `openspec-sync-specs` if specs need syncing prior to archiving.

---

## OpenSpec CLI Reference

Prefer the `--json` flag when running CLI queries programmatically:

| Command | Purpose |
|---|---|
| `npx openspec list --json` | List active changes and specs |
| `npx openspec status [--change <name>] --json` | Check artifact completion progress |
| `npx openspec instructions <artifact> --change <name> --json` | Retrieve schema-guided generation instructions |
| `npx openspec validate [--all] [--strict] --json` | Validate change artifacts and specs |
| `npx openspec archive <change> --json --yes` | Archive completed change |
