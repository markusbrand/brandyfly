---
name: openspec-propose
description: Propose a new change with all artifacts generated in one step. Use when the user wants to quickly describe what they want to build and get a complete proposal with design, specs, and tasks ready for implementation.
allowed-tools: Bash(tools/openspec-issue/openspec-issue.sh:*), Bash(gh:*), Bash(npx:*), Bash(openspec:*)
license: MIT
compatibility: Requires the tools/openspec-issue GitHub-issue adapter and the gh CLI; openspec CLI (via npx) is used only for durable-spec validation.
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.8.0"
---

> **Authoritative store: GitHub issues.** OpenSpec change state for this repository lives in GitHub issues — one issue per change, discovered by the `openspec` label — and no longer in per-change Markdown under `openspec/changes/`. Read and write change state through the repository adapter `tools/openspec-issue/openspec-issue.sh` (contract: `tools/openspec-issue/CONTRACT.md`). The adapter uses `gh` and fails explicitly when GitHub is unavailable, unauthenticated, or lacks permission; there is no local Markdown fallback. Never create per-change directories or Markdown artifacts for change state. Durable capability specs remain source-controlled under `openspec/specs/`.

Propose a new change by creating its GitHub issue and filling all planning sections in one planning-only pass.
**Adapter rule:** Use `tools/openspec-issue/openspec-issue.sh` for all change-state reads and writes. Run `tools/openspec-issue/openspec-issue.sh preflight` before reading change state and `tools/openspec-issue/openspec-issue.sh preflight --write` before any create, section update, lifecycle update, or verification recording. If preflight or any adapter command fails because GitHub is unreachable, unauthenticated, or lacks permission, stop and report the explicit failure. Do not create any local fallback artifact.

**Planning boundary**: This workflow creates planning content only. Do not edit implementation code. When planning is complete, stop and wait for a separate apply request.

With the default spec-driven schema, capture:
- `proposal` — what and why
- `requirements` — delta requirements, including capability paths relative to `openspec/specs/`
- `design` — how
- `tasks` — implementation checklist
- `verification` — initially empty or noting planning-only status

**Input**: A change name (kebab-case) OR a description of what to build.

**Steps**

1. **Understand the request**
   - Clarify any ambiguity that affects scope, behavior, compatibility, or acceptance criteria.
   - Derive a kebab-case change name and a human-readable issue title.
   - Use `spec-driven` schema metadata unless the user explicitly requests another schema.

2. **Check for existing issues**
   ```bash
   tools/openspec-issue/openspec-issue.sh preflight --write
   tools/openspec-issue/openspec-issue.sh list --state open
   tools/openspec-issue/openspec-issue.sh find "<name>"
   ```
   If the change exists, ask whether to update that issue or choose a new name.

3. **Draft every planning section**
   - Draft `proposal` with Why, What Changes, Impact, and named capabilities.
   - Draft `requirements` as delta requirements. Include each `<capability-path>` so archive/sync can merge into `openspec/specs/<capability-path>/spec.md` later.
   - Draft `design` when useful; for small changes, record why a deeper design is unnecessary.
   - Draft `tasks` as ordered checkboxes that can drive apply.
   - Draft `verification` with planning status and any assumptions.

4. **Create the issue through the adapter**
   ```bash
   tools/openspec-issue/openspec-issue.sh render-body --meta <meta.json> --proposal <proposal.md> --requirements <requirements.md> --design <design.md> --tasks <tasks.md> --verification <verification.md> > <body.md>
   tools/openspec-issue/openspec-issue.sh scan-content --body-file <body.md>
   tools/openspec-issue/openspec-issue.sh create --name "<name>" --title "<title>" --schema "<schema>" --lifecycle proposed --body-file <body.md>
   tools/openspec-issue/openspec-issue.sh validate <issue>
   tools/openspec-issue/openspec-issue.sh set-lifecycle <issue> ready
   tools/openspec-issue/openspec-issue.sh validate <issue>
   ```
   Use only transient command-input files and remove them after success.

5. **Validate durable specs only when they were touched**
   This workflow normally does not edit durable specs. If the user separately asked you to touch `openspec/specs/`, validate those source-controlled specs with:
   ```bash
   npx --yes @fission-ai/openspec@latest validate --all --strict
   ```
   This validates durable capability specs, not GitHub issue change state.

**Output**

Summarize:
- Change name and issue number
- Sections created
- Lifecycle (`ready`)
- Prompt: "The planning sections are ready for review. When you are ready, run `/opsx-apply` or ask me to apply this change."

**Guardrails**
- Planning only; do not implement code.
- Never create per-change directories or Markdown artifacts for change state.
- Write change sections only with `create` or `set-section`, then `validate`.
- If GitHub preflight or adapter validation fails, stop with no local fallback.
