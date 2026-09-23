# Workspace Guidelines & OpenSpec Workflow

## Project Overview
BrandyFly is an open-source, local-first paragliding vario and flight computer application.
- **Tech Stack**: Flutter/Dart UI (`apps/mobile`), Rust flight core (`crates/`), Kotlin/Swift native platform adapters, MapLibre/PMTiles, Go backend (`services/`).
- **Core Principles**: Safety-critical flight telemetry, offline-first reliability, low latency, deterministic replay support.

---

## Git & GitHub Workflow

All development work MUST follow a strict branch-based GitHub workflow:

1. **Automatic Feature Branch Creation**:
   - Before starting work on any new change, task, or feature, automatically create and checkout a dedicated Git branch (e.g., `feature/<change-name>`, `fix/<change-name>`, or matching the OpenSpec change name).
   - **Never work on or commit directly to the `main` or `master` branch.** Always verify you are on a dedicated feature branch before making changes.

2. **No Direct Pushes to Remote Main/Master**:
   - Pushing directly to the remote `main` or `master` branch is strictly prohibited.

3. **Pull Request (PR) Workflow**:
   - Immediately after archiving an OpenSpec change, execute a git commit (`git commit -m "chore(openspec): archive <change-name>"`), push the feature branch to GitHub (`git push -u origin <branch-name>`), and create a GitHub Pull Request associated with the branch targeting `main` (including PR status info and merge state).

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
   - Ensure a dedicated feature branch exists and is checked out before editing source code.
   - Use `openspec-apply-change` (or `/opsx-apply`) to systematically implement tasks defined in `tasks.md`.
   - Follow project standards, keeping sensor/audio loops off the Flutter main thread and preserving offline capabilities.

4. **Verify & Validate**:
   - Use `openspec-verify-change` and run `npx openspec validate --all --strict` to ensure all requirements, scenarios, and tests pass.

5. **Archive & Sync**:
   - **Mandatory Pre-requisite**: ALWAYS run verification (`openspec-verify-change` / `npx openspec validate --all --strict`) and confirm all checks pass BEFORE running archive. Never execute `openspec archive` without verifying first.
   - Use `openspec-archive-change` (or `/opsx-archive`) to promote delta specs to main `openspec/specs/` and archive the change.
   - Use `openspec-sync-specs` if specs need syncing prior to archiving.

6. **Post-Archive Commit, Push & Pull Request**:
   - Immediately following `openspec archive`, commit all remaining changes/spec promotions (`git commit -m "chore(openspec): archive <change-name>"`).
   - Push the feature branch to the GitHub remote repository (`git push -u origin <branch-name>`).
   - Create a GitHub Pull Request (using `gh pr create` or GitHub CLI/API) targeting `main` (or `master`). Include PR details and status (whether pending review or already merged).

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
