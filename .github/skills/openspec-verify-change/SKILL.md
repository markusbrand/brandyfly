---
name: openspec-verify-change
description: Verify implementation matches change artifacts. Use when the user wants to validate that implementation is complete, correct, and coherent before archiving.
allowed-tools: Bash(tools/openspec-issue/openspec-issue.sh:*), Bash(gh:*), Bash(npx:*), Bash(openspec:*)
license: MIT
compatibility: Requires the tools/openspec-issue GitHub-issue adapter and the gh CLI; openspec CLI (via npx) is used only for durable-spec validation.
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.8.0"
---

> **Authoritative store: GitHub issues.** OpenSpec change state for this repository lives in GitHub issues — one issue per change, discovered by the `openspec` label — and no longer in per-change Markdown under `openspec/changes/`. Read and write change state through the repository adapter `tools/openspec-issue/openspec-issue.sh` (contract: `tools/openspec-issue/CONTRACT.md`). The adapter uses `gh` and fails explicitly when GitHub is unavailable, unauthenticated, or lacks permission; there is no local Markdown fallback. Never create per-change directories or Markdown artifacts for change state. Durable capability specs remain source-controlled under `openspec/specs/`.

Verify that implementation matches a GitHub-issue-backed change before archive.
**Adapter rule:** Use `tools/openspec-issue/openspec-issue.sh` for all change-state reads and writes. Run `tools/openspec-issue/openspec-issue.sh preflight` before reading change state and `tools/openspec-issue/openspec-issue.sh preflight --write` before any create, section update, lifecycle update, or verification recording. If preflight or any adapter command fails because GitHub is unreachable, unauthenticated, or lacks permission, stop and report the explicit failure. Do not create any local fallback artifact.

**Input**: Optionally specify a change name. If omitted, infer only when unambiguous; otherwise list open changes and ask the user to select one.

**Steps**

1. **Select the change**
   ```bash
   tools/openspec-issue/openspec-issue.sh preflight
   tools/openspec-issue/openspec-issue.sh list --state open
   tools/openspec-issue/openspec-issue.sh find "<name>"
   ```
   Prefer changes with tasks or implementing lifecycle.

2. **Load issue sections**
   Read `proposal`, `requirements`, `design`, `tasks`, and `verification` with `get-section`. These sections replace local change artifact files.

3. **Initialize verification report**
   Track:
   - **Completeness**: task completion and requirement coverage
   - **Correctness**: implementation matches requirements and scenarios
   - **Coherence**: implementation follows design and project patterns

4. **Verify completeness**
   - Parse `tasks` checkboxes; every unchecked task is a CRITICAL issue unless evidence proves it is complete and should be checked off by apply.
   - Parse `requirements` for requirement and scenario names; look for implementation and test evidence.

5. **Verify correctness and coherence**
   - Search code and tests for evidence supporting each requirement/scenario.
   - Compare implementation decisions against `design`.
   - Prefer actionable findings with file/line references.

6. **Run targeted validation**
   Use the smallest existing test/build/lint command that covers the implemented change. If durable specs were edited, also run:
   ```bash
   npx --yes @fission-ai/openspec@latest validate --all --strict
   ```
   This validates source-controlled durable specs, not issue change state.

7. **Record verification evidence**
   If the report should be saved, run:
   ```bash
   tools/openspec-issue/openspec-issue.sh preflight --write
   tools/openspec-issue/openspec-issue.sh set-section <issue> verification --body-file <verification.md>
   tools/openspec-issue/openspec-issue.sh validate <issue>
   ```

**Output Format**

Use clear markdown:
- Summary scorecard
- CRITICAL/WARNING/SUGGESTION groups
- Code references as `file.ts:123`
- Final assessment: fix before archive, ready with warnings, or ready for archive

**Guardrails**
- Verify against issue sections only.
- Do not silently check off tasks; task updates belong to apply unless the user explicitly asks.
- Every saved verification report uses `set-section verification` and adapter validation.
- If GitHub is unavailable, provide an unsaved report only and say it was not recorded.
