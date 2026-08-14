---
name: openspec-archive-change
description: Archive a completed change in the experimental workflow. Use when the user wants to finalize and archive a change after implementation is complete.
allowed-tools: Bash(tools/openspec-issue/openspec-issue.sh:*), Bash(gh:*), Bash(npx:*), Bash(openspec:*)
license: MIT
compatibility: Requires the tools/openspec-issue GitHub-issue adapter and the gh CLI; openspec CLI (via npx) is used only for durable-spec validation.
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.8.0"
---

> **Authoritative store: GitHub issues.** OpenSpec change state for this repository lives in GitHub issues — one issue per change, discovered by the `openspec` label — and no longer in per-change Markdown under `openspec/changes/`. Read and write change state through the repository adapter `tools/openspec-issue/openspec-issue.sh` (contract: `tools/openspec-issue/CONTRACT.md`). The adapter uses `gh` and fails explicitly when GitHub is unavailable, unauthenticated, or lacks permission; there is no local Markdown fallback. Never create per-change directories or Markdown artifacts for change state. Durable capability specs remain source-controlled under `openspec/specs/`.

Archive a completed change by syncing durable specs, recording evidence, and closing the GitHub issue.
**Adapter rule:** Use `tools/openspec-issue/openspec-issue.sh` for all change-state reads and writes. Run `tools/openspec-issue/openspec-issue.sh preflight` before reading change state and `tools/openspec-issue/openspec-issue.sh preflight --write` before any create, section update, lifecycle update, or verification recording. If preflight or any adapter command fails because GitHub is unreachable, unauthenticated, or lacks permission, stop and report the explicit failure. Do not create any local fallback artifact.

`<capability-path>` is the spec directory relative to `openspec/specs/`. Preserve paths from the issue `requirements` section when resolving main specs.

**Input**: Optionally specify a change name. If omitted, infer only when unambiguous; otherwise list open changes and ask the user to select one.

**Steps**

1. **Select the change**
   ```bash
   tools/openspec-issue/openspec-issue.sh preflight --write
   tools/openspec-issue/openspec-issue.sh list --state open
   tools/openspec-issue/openspec-issue.sh find "<name>"
   ```
   Show only open changes, including issue number, lifecycle, and task progress.

2. **Read current issue state**
   Use `get-section` for `proposal`, `requirements`, `design`, `tasks`, and `verification`. Use `read <issue>` only for metadata/lifecycle context.

3. **Enforce completion prerequisites (hard blocking — no override)**
   These are contract requirements; if any fails, STOP, report which one, leave
   the issue open, and do NOT offer or accept a user override:
   - **All tasks complete:** the `tasks` section has at least one task and zero
     `- [ ]` items.
   - **Successful verification evidence:** the `verification` section records a
     completed, passing verification (not empty, a stub, or a failure).
   - **Accepted deltas synced or absent:** every accepted delta in `requirements`
     is already reflected in `openspec/specs/<capability-path>/spec.md` (verified
     in steps 4–5), or there are no deltas.

4. **Sync accepted requirement deltas**
   If the `requirements` section contains deltas, merge them into durable specs
   under `openspec/specs/` using the same intelligent merge rules as
   `openspec-sync-specs`. Every accepted delta MUST be synchronized before
   completion — there is no "complete without syncing" option. If no deltas
   exist, record "No requirement deltas" in the summary.

5. **Validate durable specs**
   After any durable spec edit, run:
   ```bash
   npx --yes @fission-ai/openspec@latest validate --all --strict
   ```
   This validates source-controlled durable specs, not issue change state. If
   validation fails, or a durable spec still does not match its accepted delta,
   stop and leave the issue open.

6. **Record archive evidence in the issue**
   Update `verification` with tasks completion status (all complete), spec sync
   summary (synced / no deltas), and validation commands and passing results.
   Then:
   ```bash
   tools/openspec-issue/openspec-issue.sh set-section <issue> verification --body-file <verification.md>
   tools/openspec-issue/openspec-issue.sh validate <issue>
   ```

7. **Complete the lifecycle**
   Only after every prerequisite in steps 3–6 holds:
   ```bash
   tools/openspec-issue/openspec-issue.sh set-lifecycle <issue> completed
   tools/openspec-issue/openspec-issue.sh validate <issue>
   ```
   `completed` closes the issue and applies `openspec:completed`.

**Output On Success**

```markdown
## Archive Complete

**Change:** <change-name>
**Issue:** #<issue>
**Lifecycle:** completed (closed)
**Specs:** synced/none/skipped with reason
**Verification:** evidence recorded in the issue
```

**Guardrails**
- Never create an archive directory or move local change files.
- Completion prerequisites (all tasks complete, successful verification evidence,
  accepted deltas synced or absent) are HARD requirements. Never offer or accept a
  user override, and never complete a change that fails any of them.
- Stop before lifecycle completion if spec validation or adapter validation fails.
- Use `set-lifecycle completed` as the only archive state transition.
