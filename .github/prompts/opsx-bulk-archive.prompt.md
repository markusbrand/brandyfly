---
description: "Archive multiple completed changes at once"
---

> **Authoritative store: GitHub issues.** OpenSpec change state for this repository lives in GitHub issues — one issue per change, discovered by the `openspec` label — and no longer in per-change Markdown under `openspec/changes/`. Read and write change state through the repository adapter `tools/openspec-issue/openspec-issue.sh` (contract: `tools/openspec-issue/CONTRACT.md`). The adapter uses `gh` and fails explicitly when GitHub is unavailable, unauthenticated, or lacks permission; there is no local Markdown fallback. Never create per-change directories or Markdown artifacts for change state. Durable capability specs remain source-controlled under `openspec/specs/`.

Complete multiple GitHub issue-backed OpenSpec changes in a single operation.

In this repository, "archive" means: sync accepted requirement deltas into durable specs under `openspec/specs/`, record verification evidence in each GitHub issue, then set lifecycle `completed` (which closes each issue). Never create archive directories.

This workflow batch-completes changes and handles spec conflicts intelligently by checking the codebase to determine what's actually implemented.

`<capability-path>` is the spec directory relative to `openspec/specs/` (for example, `user-auth` or `identity/user-auth`). Preserve the full path from each delta when resolving its durable main spec.

**Input**: None required (prompts for selection).

**Adapter contract**
- Use `tools/openspec-issue/openspec-issue.sh` for all change-state reads and writes.
- Run `preflight` before listing/finding/reading and `preflight --write` before updating verification sections or lifecycle.
- If GitHub connectivity, auth, or permission fails, stop with the adapter error. Do not create local fallback artifacts.
- Validate durable specs with `npx --yes @fission-ai/openspec@latest validate --all --strict`; this validates source-controlled specs under `openspec/specs/`, not issue change state.

**Steps**

1. **Get active changes**

   ```bash
   tools/openspec-issue/openspec-issue.sh preflight
   tools/openspec-issue/openspec-issue.sh list --state open
   ```

   If no active changes exist, inform the user and stop.

2. **Prompt for change selection**

   Ask the user to choose changes (multi-select):
   - Show each change with lifecycle, issue number, and task progress.
   - Include an option for "All changes".
   - Allow any number of selections.

   **IMPORTANT**: Do NOT auto-select. Always let the user choose.

3. **Batch validation - gather sections for all selected changes**

   For each selected change:
   - Resolve issue with `find <name>`.
   - Read `proposal`, `requirements`, `design`, `tasks`, and `verification` sections with `get-section`.
   - Count task checkboxes in the `tasks` section.
   - Extract delta requirements from the `requirements` section.
   - Treat the `requirements` section as the only delta source; do not infer deltas from unrelated text.

4. **Detect spec conflicts**

   Build a map keyed by `<capability-path>`, the exact path relative to `openspec/specs/`:

   ```text
   identity/user-auth -> [change-a, change-b]  <- CONFLICT (2+ changes)
   billing/user-auth  -> [change-c]            <- OK (different full path)
   ```

   A conflict exists when 2+ selected changes have deltas for the exact same `<capability-path>`.

5. **Resolve conflicts agentically**

   For each conflict:
   - Read the relevant delta requirements from each conflicting issue.
   - Search the codebase for implementation evidence.
   - Determine resolution:
     - If only one change is implemented -> sync that change's delta; the other
       change's accepted delta is unsynced, so that change is **ineligible** and
       stays open.
     - If multiple are implemented -> apply in chronological order when known, otherwise ask the user.
     - If none are implemented -> the accepted deltas cannot be synced, so those
       changes are **ineligible** and stay open (never completed unsynced).
   - Record inclusion/exclusion decisions per delta with rationale.

5a. **Gate each change on completion prerequisites (hard blocking — no override)**

   Classify each selected change as **eligible** or **ineligible**. A change is
   ineligible and MUST be left open if any contract requirement fails, regardless
   of user confirmation:
   - the `tasks` section has any `- [ ]` item or no tasks;
   - the `verification` section lacks a completed, passing verification;
   - any accepted delta in its `requirements` cannot be synced.

6. **Show consolidated status table**

   Display a table summarizing all selected changes (Change, Issue, Tasks,
   Verification, Specs, Conflicts, Eligible?). Show conflict resolutions and, for
   each ineligible change, the failed prerequisite that keeps it open.

7. **Confirm batch operation**

   Ask one confirmation question that only chooses among **eligible** changes:
   - "Complete all eligible changes"
   - "Complete a chosen subset of eligible changes"
   - "Cancel"

   Route by intent:
   - Cancel -> stop with no writes.
   - Complete all eligible -> proceed with every eligible change.
   - Subset -> proceed with the chosen eligible changes; record the rest as not selected.

   Confirmation can never promote an ineligible change; ineligible changes are
   always left open.

8. **Execute completion for each confirmed eligible change**

   Before processing, run:
   ```bash
   tools/openspec-issue/openspec-issue.sh preflight --write
   ```

   For each confirmed eligible change, carrying recorded conflict decisions:

   a. **Sync accepted deltas**
      - Run `/opsx-sync` inline for the change's accepted deltas (every accepted
        delta must sync). Do not delegate to background work.
      - For conflicts, apply in resolved order.
      - If a change has no deltas, no sync is required.

   b. **Verify durable specs before closing the issue**
      - Compare accepted deltas against durable specs at `openspec/specs/<capability-path>/spec.md`.
      - Run `npx --yes @fission-ai/openspec@latest validate --all --strict` after durable spec writes.
      - If sync or validation fails, record the failure and do not close that issue.

   c. **Record verification evidence**
      - Update that issue's `verification` section with task status, sync status, validation output, and any excluded-delta rationale for other changes.
      - Run `set-section <issue> verification --body-file <verification-file>` and `validate <issue>`.

   d. **Complete the issue**
      ```bash
      tools/openspec-issue/openspec-issue.sh set-lifecycle <issue> completed
      tools/openspec-issue/openspec-issue.sh validate <issue>
      ```

   e. **Track outcome**
      - Success: completed successfully.
      - Failed: error during sync, validation, issue update, or lifecycle transition.
      - Left open (ineligible): a completion prerequisite was not met.
      - Not selected: user chose a subset that excluded this eligible change.

9. **Display summary**

   ```markdown
   ## Bulk Completion Complete

   Completed 3 changes:
   - schema-management-cli (#10)
   - project-config (#11)
   - add-oauth (#12)

   Skipped 1 change:
   - add-verify-skill (user chose not to complete incomplete work)

   Spec sync summary:
   - 4 deltas synced to durable specs
   - 1 delta sync skipped (add-jwt, identity/user-auth: implementation not found)
   - 1 conflict resolved
   ```

   If any failures, list them with exact adapter or validation errors.

**Conflict Resolution Examples**

Example 1: Only one implemented
```text
Conflict: openspec/specs/auth/spec.md touched by [add-oauth, add-jwt]

Checking add-oauth:
- Delta adds "OAuth Provider Integration" requirement
- Searching codebase... found src/auth/oauth.ts implementing OAuth flow

Checking add-jwt:
- Delta adds "JWT Token Handling" requirement
- Searching codebase... no JWT implementation found

Resolution: Only add-oauth is implemented. Will sync add-oauth specs only.
```

Example 2: Both implemented
```text
Conflict: openspec/specs/api/spec.md touched by [add-rest-api, add-graphql]

Both are implemented. Apply older delta first, then newer delta, unless the user chooses a different order.
```

**Guardrails**
- Allow any number of changes, but always prompt for selection.
- Per-change completion prerequisites (all tasks complete, successful verification
  evidence, all accepted deltas synced) are HARD requirements. The single batch
  confirmation only selects among eligible changes and can never complete an
  ineligible one; ineligible changes are always left open.
- Detect spec conflicts early and resolve by checking codebase.
- A change whose accepted delta cannot be synced (implementation missing) is
  ineligible and stays open — never complete it with an unsynced accepted delta.
- Use a single confirmation for the batch.
- Never complete anything after the user cancels.
- Track and report success, left-open (ineligible), not-selected, and failure outcomes.
- Never close an issue while spec sync is still in flight.
- Validate durable specs before closing any issue whose deltas were synced.
- Changes with no requirement deltas continue without spec sync.
- Never create archive directories; completion is represented by lifecycle `completed` and closed GitHub issues.
- Never create a per-change directory or Markdown artifact under `openspec/changes/`; change state lives only in GitHub issues via the adapter.
