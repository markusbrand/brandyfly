---
name: openspec-bulk-archive-change
description: Archive multiple completed changes at once. Use when archiving several parallel changes.
allowed-tools: Bash(tools/openspec-issue/openspec-issue.sh:*), Bash(gh:*), Bash(npx:*), Bash(openspec:*)
license: MIT
compatibility: Requires the tools/openspec-issue GitHub-issue adapter and the gh CLI; openspec CLI (via npx) is used only for durable-spec validation.
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.8.0"
---

> **Authoritative store: GitHub issues.** OpenSpec change state for this repository lives in GitHub issues — one issue per change, discovered by the `openspec` label — and no longer in per-change Markdown under `openspec/changes/`. Read and write change state through the repository adapter `tools/openspec-issue/openspec-issue.sh` (contract: `tools/openspec-issue/CONTRACT.md`). The adapter uses `gh` and fails explicitly when GitHub is unavailable, unauthenticated, or lacks permission; there is no local Markdown fallback. Never create per-change directories or Markdown artifacts for change state. Durable capability specs remain source-controlled under `openspec/specs/`.

Archive multiple completed changes by syncing durable specs and closing their GitHub issues.
**Adapter rule:** Use `tools/openspec-issue/openspec-issue.sh` for all change-state reads and writes. Run `tools/openspec-issue/openspec-issue.sh preflight` before reading change state and `tools/openspec-issue/openspec-issue.sh preflight --write` before any create, section update, lifecycle update, or verification recording. If preflight or any adapter command fails because GitHub is unreachable, unauthenticated, or lacks permission, stop and report the explicit failure. Do not create any local fallback artifact.

This skill batch-completes selected OpenSpec issue changes and resolves spec conflicts by checking what is actually implemented.

`<capability-path>` is the spec directory relative to `openspec/specs/`. Preserve full paths from each issue's `requirements` section.

**Input**: None required; prompt for selection.

**Steps**

1. **List open changes**
   ```bash
   tools/openspec-issue/openspec-issue.sh preflight --write
   tools/openspec-issue/openspec-issue.sh list --state open
   ```
   If no open changes exist, inform the user and stop.

2. **Prompt for selection**
   Ask the user to choose one or more changes. Do not auto-select. Show change name, issue number, lifecycle, and task progress.

3. **Gather issue state for selected changes**
   For each selected change:
   ```bash
   tools/openspec-issue/openspec-issue.sh find "<name>"
   tools/openspec-issue/openspec-issue.sh get-section <issue> requirements
   tools/openspec-issue/openspec-issue.sh get-section <issue> tasks
   tools/openspec-issue/openspec-issue.sh get-section <issue> verification
   ```
   Also read `proposal` and `design` when needed for context. Treat issue sections as the only change-state source.

4. **Gate each change on completion prerequisites (hard blocking — no override)**
   Independently classify every selected change as **eligible** or **ineligible**.
   A change is ineligible (and MUST be left open, excluded from completion) if any
   of these contract requirements fails — no user confirmation can override them:
   - the `tasks` section has any `- [ ]` item or contains no tasks;
   - the `verification` section lacks a completed, passing verification;
   - any accepted delta in its `requirements` cannot be synchronized (see steps
     5–6), i.e. it would otherwise be completed with an unsynced accepted delta.
   Only eligible changes proceed to completion.

5. **Detect durable spec conflicts**
   Build a map keyed by exact `<capability-path>` from each eligible issue's
   requirements section. A conflict exists when two or more selected changes touch
   the same capability path.

6. **Resolve conflicts agentically**
   For each conflict:
   - Read the conflicting requirements from each issue.
   - Search the codebase for implementation evidence.
   - If only one change is implemented, sync that one; the other change's accepted
     delta is unsynced, so that change becomes **ineligible** and stays open.
   - If multiple are implemented, apply in chronological or user-confirmed order,
     with later accepted changes overriding only where appropriate.
   - If none are implemented, the accepted deltas cannot be synced, so those
     changes are **ineligible** and stay open (never complete them unsynced).
   Record inclusion/exclusion decisions per change and capability path.

7. **Show consolidated status and confirm scope**
   Present a table with per-change eligibility, task completion, verification
   status, spec deltas, conflicts, and planned sync decisions. Ask one
   confirmation question, but the confirmation only chooses which **eligible**
   changes to archive — it can never promote an ineligible change. If the user
   cancels, archive nothing.

8. **Execute confirmed batch**
   For each confirmed **eligible** change in resolved order:
   - Sync its accepted deltas into `openspec/specs/` using the intelligent merge
     rules (every accepted delta must sync).
   - Validate durable specs after edits:
     ```bash
     npx --yes @fission-ai/openspec@latest validate --all --strict
     ```
   - Record verification evidence and sync decisions in the issue `verification`
     section with `set-section`, then validate.
   - Complete the issue:
     ```bash
     tools/openspec-issue/openspec-issue.sh set-lifecycle <issue> completed
     tools/openspec-issue/openspec-issue.sh validate <issue>
     ```
   If a change fails sync, durable spec validation, or adapter validation, leave
   that issue open and continue only when doing so cannot corrupt later changes.

9. **Display summary**
   Report completed, ineligible/left-open (with the failed prerequisite), and
   failed issues; synced and excluded delta specs; conflicts resolved; and
   validation commands run.

**Output On Success**

```markdown
## Bulk Archive Complete

Completed issues:
- <change-1> (#<issue>)
- <change-2> (#<issue>)

Spec sync summary:
- N delta specs synced to durable specs
- M delta specs excluded with rationale
- K conflicts resolved
```

**Guardrails**
- Always prompt for selection and confirmation.
- Per-change completion prerequisites (all tasks complete, successful verification
  evidence, all accepted deltas synced) are HARD requirements. Confirmation only
  selects among eligible changes; it can never complete an ineligible change, and
  an ineligible change is always left open.
- Never create archive directories or move local change files.
- Carry per-delta included/excluded decisions into execution.
- Sync and verify only included deltas.
- Record evidence before setting lifecycle `completed`.
- Stop explicitly on GitHub/auth/permission failures; do not create fallback artifacts.
