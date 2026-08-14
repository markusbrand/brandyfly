---
name: openspec-sync-specs
description: Sync delta specs from a change to main specs. Use when the user wants to update main specs with changes from a delta spec, without archiving the change.
allowed-tools: Bash(tools/openspec-issue/openspec-issue.sh:*), Bash(gh:*), Bash(npx:*), Bash(openspec:*)
license: MIT
compatibility: Requires the tools/openspec-issue GitHub-issue adapter and the gh CLI; openspec CLI (via npx) is used only for durable-spec validation.
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.8.0"
---

> **Authoritative store: GitHub issues.** OpenSpec change state for this repository lives in GitHub issues — one issue per change, discovered by the `openspec` label — and no longer in per-change Markdown under `openspec/changes/`. Read and write change state through the repository adapter `tools/openspec-issue/openspec-issue.sh` (contract: `tools/openspec-issue/CONTRACT.md`). The adapter uses `gh` and fails explicitly when GitHub is unavailable, unauthenticated, or lacks permission; there is no local Markdown fallback. Never create per-change directories or Markdown artifacts for change state. Durable capability specs remain source-controlled under `openspec/specs/`.

Sync accepted requirement deltas from a change issue into durable source-controlled specs.
**Adapter rule:** Use `tools/openspec-issue/openspec-issue.sh` for all change-state reads and writes. Run `tools/openspec-issue/openspec-issue.sh preflight` before reading change state and `tools/openspec-issue/openspec-issue.sh preflight --write` before any create, section update, lifecycle update, or verification recording. If preflight or any adapter command fails because GitHub is unreachable, unauthenticated, or lacks permission, stop and report the explicit failure. Do not create any local fallback artifact.

This is an **agent-driven** operation: read the issue `requirements` section and edit `openspec/specs/` intelligently. It does not complete or close the change by itself.

`<capability-path>` is the spec directory relative to `openspec/specs/` (for example, `user-auth` or `identity/user-auth`). Preserve full paths from the issue requirements when resolving main specs.

**Input**: Optionally specify a change name. If omitted, infer only when unambiguous; otherwise list open changes and ask the user to select one.

**Steps**

1. **Select the change**
   ```bash
   tools/openspec-issue/openspec-issue.sh preflight
   tools/openspec-issue/openspec-issue.sh list --state open
   tools/openspec-issue/openspec-issue.sh find "<name>"
   ```

2. **Read delta requirements from the issue**
   ```bash
   tools/openspec-issue/openspec-issue.sh get-section <issue> requirements
   ```
   Treat this section as the only delta source. If it is empty or lacks concrete capability paths, report that there is nothing safe to sync and stop.

3. **Resolve target durable specs**
   Main specs live under `openspec/specs/<capability-path>/spec.md` in the repository. They are source-controlled durable capability specs, not change state.

4. **Apply each delta intelligently**
   For each capability path selected by the caller or found in the requirements section:
   - Read the delta requirement content from the issue.
   - Read the current main spec if it exists.
   - Merge ADDED, MODIFIED, REMOVED, and RENAMED requirements while preserving existing main-spec content not mentioned by the delta.
   - Never copy a delta wholesale into a main spec; main specs must have normal `## Requirements` content and no delta operation headers.
   - Only delete a spec file when the accepted delta retires the capability and no requirements remain.

5. **Validate durable specs**
   ```bash
   npx --yes @fission-ai/openspec@latest validate --all --strict
   ```
   This validates source-controlled durable specs under `openspec/specs/`; it does not validate GitHub issue change state. If validation fails, report the errors and do not claim success.

6. **Optional evidence recording**
   If the user asked to record sync evidence, run `preflight --write`, update the issue `verification` section with `set-section`, and `validate <issue>`.

**Output On Success**

```markdown
## Specs Synced: <change-name>

Updated durable specs:
- <capability-path>: added/modified/removed/renamed requirements

Main specs are updated. The change remains open until archive marks it completed.
```

**Guardrails**
- Use only the issue `requirements` section for deltas.
- Preserve existing main-spec content not mentioned by the delta.
- The operation should be idempotent.
- Stop on unclear deltas rather than guessing capability paths.
- Never create archive directories or local change artifacts.
