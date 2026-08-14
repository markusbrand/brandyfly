---
name: openspec-update-change
description: Update an OpenSpec change by revising its existing planning artifacts and keeping them coherent with one another. Use when the user wants to revise a change's plan, fold new decisions into it, or reconcile its artifacts after an edit. Never edits code.
allowed-tools: Bash(tools/openspec-issue/openspec-issue.sh:*), Bash(gh:*), Bash(npx:*), Bash(openspec:*)
license: MIT
compatibility: Requires the tools/openspec-issue GitHub-issue adapter and the gh CLI; openspec CLI (via npx) is used only for durable-spec validation.
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.8.0"
---

> **Authoritative store: GitHub issues.** OpenSpec change state for this repository lives in GitHub issues — one issue per change, discovered by the `openspec` label — and no longer in per-change Markdown under `openspec/changes/`. Read and write change state through the repository adapter `tools/openspec-issue/openspec-issue.sh` (contract: `tools/openspec-issue/CONTRACT.md`). The adapter uses `gh` and fails explicitly when GitHub is unavailable, unauthenticated, or lacks permission; there is no local Markdown fallback. Never create per-change directories or Markdown artifacts for change state. Durable capability specs remain source-controlled under `openspec/specs/`.

Revise an existing change's planning sections and keep them coherent. Never edit implementation code.
**Adapter rule:** Use `tools/openspec-issue/openspec-issue.sh` for all change-state reads and writes. Run `tools/openspec-issue/openspec-issue.sh preflight` before reading change state and `tools/openspec-issue/openspec-issue.sh preflight --write` before any create, section update, lifecycle update, or verification recording. If preflight or any adapter command fails because GitHub is unreachable, unauthenticated, or lacks permission, stop and report the explicit failure. Do not create any local fallback artifact.

**Input**: Optionally specify a change name. If omitted, infer only when unambiguous; otherwise list open changes and ask the user to select one.

**Steps**

1. **Select and resolve the issue**
   ```bash
   tools/openspec-issue/openspec-issue.sh preflight
   tools/openspec-issue/openspec-issue.sh list --state open
   tools/openspec-issue/openspec-issue.sh find "<name>"
   ```
   Announce the selected change and issue number.

2. **Read existing planning sections**
   Use `get-section` for `proposal`, `requirements`, `design`, `tasks`, and `verification`. If schema or lifecycle metadata is needed, use `read <issue>` and parse the hidden metadata block. Do not look for `changeRoot`, `artifactPaths`, `.openspec.yaml`, or local artifact files.

3. **Understand the requested revision**
   - If the user requested a specific edit, apply that edit as the anchor.
   - If they asked for coherence, compare all issue sections for contradictions, gaps, stale tasks, and mismatched assumptions.
   - A later-section edit may require earlier-section changes and vice versa.

4. **Confirm proposed section changes**
   Show each proposed revision and why. Write only revisions the user confirms. If the user rejects one, leave that section unchanged.

5. **Write confirmed revisions**
   ```bash
   tools/openspec-issue/openspec-issue.sh preflight --write
   tools/openspec-issue/openspec-issue.sh set-section <issue> <section> --body-file <section.md>
   tools/openspec-issue/openspec-issue.sh validate <issue>
   ```
   Repeat per revised section. If revisions move the change back into planning, use `set-lifecycle <issue> proposed`; if all planning sections remain ready, use `set-lifecycle <issue> ready`, then `validate`.

6. **Point to the next step**
   - Missing planning sections → suggest `/opsx-continue`.
   - Plan changed after implementation started → suggest `/opsx-apply` to carry the delta into code.
   - Implemented and verified → suggest `/opsx-archive`.

**Output**

Show:
- Which sections were revised
- Which proposed revisions were rejected
- Any deferred missing sections
- Recommended next command

**Guardrails**
- Planning sections only; never edit implementation code.
- Do not create missing sections unless the user asked to continue/create them.
- Never use local change directories as authoritative storage.
- Every issue write is followed by adapter `validate`.
- Stop without fallback on adapter/preflight failures.
