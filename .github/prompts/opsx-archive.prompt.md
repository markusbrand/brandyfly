---
description: "Archive a completed change in the experimental workflow"
---

> **Authoritative store: GitHub issues.** OpenSpec change state for this repository lives in GitHub issues — one issue per change, discovered by the `openspec` label — and no longer in per-change Markdown under `openspec/changes/`. Read and write change state through the repository adapter `tools/openspec-issue/openspec-issue.sh` (contract: `tools/openspec-issue/CONTRACT.md`). The adapter uses `gh` and fails explicitly when GitHub is unavailable, unauthenticated, or lacks permission; there is no local Markdown fallback. Never create per-change directories or Markdown artifacts for change state. Durable capability specs remain source-controlled under `openspec/specs/`.

Complete a finished GitHub issue-backed OpenSpec change.

In this repository, "archive" means: sync accepted requirement deltas into durable specs under `openspec/specs/`, record verification evidence in the GitHub issue, then set lifecycle `completed` (which closes the issue). Never create an archive directory.

`<capability-path>` is the spec directory relative to `openspec/specs/` (for example, `user-auth` or `identity/user-auth`). Preserve the full path from each delta when resolving its durable main spec.

**Input**: Optionally specify a change name after `/opsx-archive` (e.g., `/opsx-archive add-auth`). If omitted, check if it can be inferred from conversation context. If vague or ambiguous you MUST prompt for available changes.

**Adapter contract**
- Use `tools/openspec-issue/openspec-issue.sh` for all change-state reads and writes.
- Run `preflight` before listing/finding/reading and `preflight --write` before recording evidence or changing lifecycle.
- If GitHub connectivity, auth, or permission fails, stop with the adapter error. Do not create local fallback artifacts.
- Validate durable specs with `npx --yes @fission-ai/openspec@latest validate --all --strict`; this validates source-controlled specs under `openspec/specs/`, not issue change state.

**Steps**

1. **Select the change**

   If a name is provided, use `find <name>`. Otherwise infer from context, auto-select if only one open change exists, or run:
   ```bash
   tools/openspec-issue/openspec-issue.sh preflight
   tools/openspec-issue/openspec-issue.sh list --state open
   ```
   When prompting, show only open changes. Always announce: "Using change: <name>" and how to override.

2. **Read planning and verification sections**

   ```bash
   tools/openspec-issue/openspec-issue.sh get-section <issue> proposal
   tools/openspec-issue/openspec-issue.sh get-section <issue> requirements
   tools/openspec-issue/openspec-issue.sh get-section <issue> design
   tools/openspec-issue/openspec-issue.sh get-section <issue> tasks
   tools/openspec-issue/openspec-issue.sh get-section <issue> verification
   ```

3. **Enforce completion prerequisites (hard blocking — no override)**

   The following are contract requirements. If any is not satisfied, STOP,
   report exactly which prerequisite failed, leave the issue open, and do NOT
   offer or accept a user override:

   - **All tasks complete.** The `tasks` section must contain at least one task
     and zero `- [ ]` (incomplete) items. If any task is incomplete or the tasks
     list is empty, stop.
   - **Successful verification evidence.** The `verification` section must record
     a completed verification with a passing result (see `/opsx-verify`). If it
     is empty, a stub, or records a failure, stop.
   - **Accepted requirement deltas are synchronized or genuinely absent** (checked
     in step 4).

4. **Determine and enforce requirement sync state (hard blocking)**

   Use the `requirements` section as the only source of change deltas.

   - If there are **no** delta requirements, syncing is not required — proceed.
   - If deltas exist, each accepted delta MUST already be reflected in the durable
     main spec at `openspec/specs/<capability-path>/spec.md`. Compare every delta
     against its durable spec. If any accepted delta is not yet synchronized,
     complete the sync in step 5 first. Completion MUST NOT proceed while any
     accepted delta is unsynced — there is no "complete without syncing" option.

5. **Synchronize accepted deltas into durable specs**

   If any accepted delta is unsynced, run the `/opsx-sync` workflow inline (never
   in the background) or merge the deltas into `openspec/specs/` directly, then:
   ```bash
   npx --yes @fission-ai/openspec@latest validate --all --strict
   ```
   If validation fails, or a durable spec still does not match its accepted
   delta, report the mismatch and STOP without completing the issue.

6. **Record final verification evidence**

   Append completion evidence to the `verification` section, including task
   status (all complete), sync status (synced / no deltas), and the durable-spec
   validation command and passing result. Then:
   ```bash
   tools/openspec-issue/openspec-issue.sh preflight --write
   tools/openspec-issue/openspec-issue.sh set-section <issue> verification --body-file <verification-file>
   tools/openspec-issue/openspec-issue.sh validate <issue>
   ```

7. **Complete the issue**

   Only after every prerequisite in steps 3–6 is satisfied:
   ```bash
   tools/openspec-issue/openspec-issue.sh set-lifecycle <issue> completed
   tools/openspec-issue/openspec-issue.sh validate <issue>
   ```

8. **Display summary**

   Show:
   - Change name and issue number
   - Spec sync status
   - Durable spec validation status
   - Task completion status
   - Any warnings

**Output On Success**

```markdown
## Change Completed

**Change:** <change-name>
**Issue:** #<issue> (closed)
**Specs:** ✓ Synced to `openspec/specs/`
**Validation:** ✓ `npx --yes @fission-ai/openspec@latest validate --all --strict`

All artifacts complete. All tasks complete.
```

**Output On Blocked (a prerequisite is not satisfied)**

```markdown
## Change Not Completed

**Change:** <change-name>
**Issue:** #<issue> (still open)

Blocked by unmet completion prerequisites:
- <e.g. 2 incomplete tasks remain>
- <e.g. verification evidence missing/failed>
- <e.g. accepted delta for <capability-path> not synced>

Resolve the above (e.g. `/opsx-apply`, `/opsx-verify`, `/opsx-sync`) and re-run.
```

**Guardrails**
- Announce the selected change; prompt for selection when ambiguous.
- Completion prerequisites (all tasks complete, successful verification evidence,
  accepted deltas synced or absent) are HARD requirements. Never offer or accept
  a user override, and never complete a change that fails any of them.
- If sync is required, run it inline and verify durable specs before closing the issue.
- Never complete a change while spec sync is still in flight.
- Never create an archive directory; completion is represented by lifecycle `completed` and the closed GitHub issue.
- Never create a per-change directory or Markdown artifact under `openspec/changes/`; change state lives only in GitHub issues via the adapter.
