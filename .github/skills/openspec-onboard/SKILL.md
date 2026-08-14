---
name: openspec-onboard
description: Guided onboarding for OpenSpec - walk through a complete workflow cycle with narration and real codebase work.
allowed-tools: Bash(tools/openspec-issue/openspec-issue.sh:*), Bash(gh:*), Bash(npx:*), Bash(openspec:*)
license: MIT
compatibility: Requires the tools/openspec-issue GitHub-issue adapter and the gh CLI; openspec CLI (via npx) is used only for durable-spec validation.
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.8.0"
---

> **Authoritative store: GitHub issues.** OpenSpec change state for this repository lives in GitHub issues — one issue per change, discovered by the `openspec` label — and no longer in per-change Markdown under `openspec/changes/`. Read and write change state through the repository adapter `tools/openspec-issue/openspec-issue.sh` (contract: `tools/openspec-issue/CONTRACT.md`). The adapter uses `gh` and fails explicitly when GitHub is unavailable, unauthenticated, or lacks permission; there is no local Markdown fallback. Never create per-change directories or Markdown artifacts for change state. Durable capability specs remain source-controlled under `openspec/specs/`.

Guide the user through their first complete GitHub-issue-backed OpenSpec workflow cycle with narration and real codebase work.
**Adapter rule:** Use `tools/openspec-issue/openspec-issue.sh` for all change-state reads and writes. Run `tools/openspec-issue/openspec-issue.sh preflight` before reading change state and `tools/openspec-issue/openspec-issue.sh preflight --write` before any create, section update, lifecycle update, or verification recording. If preflight or any adapter command fails because GitHub is unreachable, unauthenticated, or lacks permission, stop and report the explicit failure. Do not create any local fallback artifact.

---

## Preflight

Start by proving the issue adapter can read and later write change state:
```bash
tools/openspec-issue/openspec-issue.sh preflight
tools/openspec-issue/openspec-issue.sh preflight --write
```
If either fails, explain the GitHub connectivity/auth/permission problem and stop the workflow. Do not create local change artifacts.

---

## Phase 1: Welcome

Explain that OpenSpec changes are GitHub issues, while durable capability specs live in `openspec/specs/`. The cycle is:
1. Pick a small task
2. Explore briefly
3. Create one issue for the change
4. Fill proposal → requirements → design → tasks sections
5. Apply tasks
6. Sync accepted requirement deltas into durable specs
7. Record verification and mark the issue completed

---

## Phase 2: Task Selection

Scan the codebase for small improvement opportunities: TODOs, missing error handling, untested functions, type issues, debug artifacts, or missing validation. Present 3-4 concrete options and let the user choose. If the task is too large, help slice it smaller but respect the user's choice.

---

## Phase 3: Explore Demo

Investigate the relevant files, draw a small diagram if helpful, and explain how `/opsx-explore` supports this thinking. Pause for acknowledgment before creating change state.

---

## Phase 4: Create the Change Issue

Explain:
```text
A change is one GitHub issue with managed sections for proposal, requirements, design, tasks, and verification. The issue is the authoritative change state.
```

Do:
```bash
tools/openspec-issue/openspec-issue.sh preflight --write
tools/openspec-issue/openspec-issue.sh render-body --meta <meta.json> --proposal <proposal.md> --requirements <requirements.md> --design <design.md> --tasks <tasks.md> --verification <verification.md> > <body.md>
tools/openspec-issue/openspec-issue.sh scan-content --body-file <body.md>
tools/openspec-issue/openspec-issue.sh create --name "<derived-name>" --title "<title>" --schema spec-driven --lifecycle proposed --body-file <body.md>
tools/openspec-issue/openspec-issue.sh validate <issue>
```
Show the issue number, not a local path.

---

## Phase 5: Proposal

Draft the `proposal` section, show it, and pause for approval. After approval:
```bash
tools/openspec-issue/openspec-issue.sh set-section <issue> proposal --body-file <proposal.md>
tools/openspec-issue/openspec-issue.sh validate <issue>
```

---

## Phase 6: Requirements

Draft delta requirements in the `requirements` section. Include `<capability-path>` values relative to `openspec/specs/` so archive can merge them later. Show the requirement/scenario format, pause if needed, then save with `set-section <issue> requirements --body-file <requirements.md>` and validate.

---

## Phase 7: Design

Draft the `design` section with context, goals/non-goals, and decisions. For a tiny change, explicitly record why no deeper design is needed. Save with `set-section <issue> design --body-file <design.md>` and validate.

---

## Phase 8: Tasks

Draft ordered checkbox tasks in the `tasks` section. Save them, validate, then mark the issue ready:
```bash
tools/openspec-issue/openspec-issue.sh set-section <issue> tasks --body-file <tasks.md>
tools/openspec-issue/openspec-issue.sh validate <issue>
tools/openspec-issue/openspec-issue.sh set-lifecycle <issue> ready
tools/openspec-issue/openspec-issue.sh validate <issue>
```
Pause before implementation.

---

## Phase 9: Apply

Set lifecycle to implementing, then work task-by-task:
```bash
tools/openspec-issue/openspec-issue.sh set-lifecycle <issue> implementing
tools/openspec-issue/openspec-issue.sh get-section <issue> tasks
```
For each task: announce it, implement minimal code changes, run appropriate verification, update the task checkbox via `set-section <issue> tasks --body-file <tasks.md>`, record evidence in `verification` via `set-section`, and validate before starting the next task.

---

## Phase 10: Archive / Complete

Explain that completion no longer creates an archive directory. Instead:
1. Sync accepted deltas from the issue `requirements` section into `openspec/specs/`.
2. Validate durable specs:
   ```bash
   npx --yes @fission-ai/openspec@latest validate --all --strict
   ```
3. Record verification evidence in the issue `verification` section.
4. Close the issue through lifecycle:
   ```bash
   tools/openspec-issue/openspec-issue.sh set-lifecycle <issue> completed
   tools/openspec-issue/openspec-issue.sh validate <issue>
   ```

---

## Recap & Guardrails

- Follow EXPLAIN → DO → SHOW → PAUSE at teaching checkpoints.
- Use real codebase tasks.
- Keep narration light during implementation.
- Never create local per-change storage; there is no local fallback.
- Source-controlled durable specs are validated with `npx --yes @fission-ai/openspec@latest validate --all --strict` after they are edited.
