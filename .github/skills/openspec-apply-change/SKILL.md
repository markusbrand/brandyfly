---
name: openspec-apply-change
description: Implement tasks from an OpenSpec change. Use when the user wants to start implementing, continue implementation, or work through tasks.
allowed-tools: Bash(tools/openspec-issue/openspec-issue.sh:*), Bash(gh:*), Bash(npx:*), Bash(openspec:*)
license: MIT
compatibility: Requires the tools/openspec-issue GitHub-issue adapter and the gh CLI; openspec CLI (via npx) is used only for durable-spec validation.
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.8.0"
---

> **Authoritative store: GitHub issues.** OpenSpec change state for this repository lives in GitHub issues — one issue per change, discovered by the `openspec` label — and no longer in per-change Markdown under `openspec/changes/`. Read and write change state through the repository adapter `tools/openspec-issue/openspec-issue.sh` (contract: `tools/openspec-issue/CONTRACT.md`). The adapter uses `gh` and fails explicitly when GitHub is unavailable, unauthenticated, or lacks permission; there is no local Markdown fallback. Never create per-change directories or Markdown artifacts for change state. Durable capability specs remain source-controlled under `openspec/specs/`.

Implement tasks from a GitHub-issue-backed OpenSpec change.
**Adapter rule:** Use `tools/openspec-issue/openspec-issue.sh` for all change-state reads and writes. Run `tools/openspec-issue/openspec-issue.sh preflight` before reading change state and `tools/openspec-issue/openspec-issue.sh preflight --write` before any create, section update, lifecycle update, or verification recording. If preflight or any adapter command fails because GitHub is unreachable, unauthenticated, or lacks permission, stop and report the explicit failure. Do not create any local fallback artifact.

**Input**: Optionally specify a change name. If omitted, infer only when unambiguous; otherwise list open changes and ask the user to select one.

**Steps**

1. **Select the change**
   ```bash
   tools/openspec-issue/openspec-issue.sh preflight --write
   tools/openspec-issue/openspec-issue.sh list --state open
   tools/openspec-issue/openspec-issue.sh find "<name>"
   ```
   Announce the selected change and issue number.

2. **Read planning sections from the issue**
   ```bash
   tools/openspec-issue/openspec-issue.sh get-section <issue> proposal
   tools/openspec-issue/openspec-issue.sh get-section <issue> requirements
   tools/openspec-issue/openspec-issue.sh get-section <issue> design
   tools/openspec-issue/openspec-issue.sh get-section <issue> tasks
   tools/openspec-issue/openspec-issue.sh get-section <issue> verification
   ```
   Treat issue sections as the only change-state source. Do not look for local `proposal.md`, `tasks.md`, `changeRoot`, or `artifactPaths`.

3. **Enter the implementing lifecycle through valid transitions**

   The adapter only permits `ready -> implementing` (and `proposed -> ready`).
   Read the current lifecycle and advance it through the allowed path — never
   attempt `proposed -> implementing` directly (the adapter refuses it).

   Determine the current lifecycle from the issue metadata (the `list`/`validate`
   output reports it). Then:

   - **implementing** — already implementing; continue to step 4.
   - **ready** — advance to implementing:
     ```bash
     tools/openspec-issue/openspec-issue.sh preflight --write
     tools/openspec-issue/openspec-issue.sh set-lifecycle <issue> ready        # no-op if already ready
     tools/openspec-issue/openspec-issue.sh set-lifecycle <issue> implementing
     tools/openspec-issue/openspec-issue.sh validate <issue>
     ```
   - **proposed** — first confirm the change is **ready** (readiness criteria
     below). If ready, promote `proposed -> ready -> implementing`:
     ```bash
     tools/openspec-issue/openspec-issue.sh set-lifecycle <issue> ready
     tools/openspec-issue/openspec-issue.sh set-lifecycle <issue> implementing
     ```
     If it is **not** ready, STOP and suggest `/opsx-continue`; do not force the
     transition.
   - **completed** — the issue is closed/archived; refuse to apply.

   **Readiness criteria (all must hold before `ready`):** the `proposal`,
   `requirements`, `design`, and `tasks` sections are all present and non-empty,
   and the `tasks` section contains at least one actionable `- [ ]`/`- [x]` item.
   If any planning section is missing or the tasks list is empty, the change is
   not ready — stop and route to `/opsx-continue`.

4. **Show current progress**
   Parse the `tasks` section for `- [ ]` and `- [x]` checkboxes. Display total, completed, and remaining tasks.

5. **Implement tasks one at a time**
   For each pending task:
   - Announce the task.
   - Make minimal, focused code changes.
   - Run the smallest existing verification command that covers the change.
   - If verification passes, update the `tasks` section checkbox and record evidence in `verification` before starting the next task:
     ```bash
     tools/openspec-issue/openspec-issue.sh set-section <issue> tasks --body-file <tasks.md>
     tools/openspec-issue/openspec-issue.sh set-section <issue> verification --body-file <verification.md>
     tools/openspec-issue/openspec-issue.sh validate <issue>
     ```
   - If verification fails or the task is unclear, pause and report the blocker without checking off the task.

6. **On completion or pause**
   Show tasks completed this session, overall progress, and any verification evidence recorded. If all tasks are complete, suggest `/opsx-verify` or `/opsx-archive`.

**Output During Implementation**

```markdown
## Implementing: <change-name>

Working on task 3/7: <task description>
✓ Task complete — evidence recorded in issue verification section
```

**Guardrails**
- Keep going through tasks until done or blocked.
- Always read issue sections before starting.
- Update the issue `tasks` and `verification` sections after each verified task, then validate before the next task.
- Do not mark a task complete before verification succeeds.
- Keep code changes minimal and scoped to each task.
- Never use local change Markdown as authoritative state.
- Stop explicitly on adapter/GitHub failures; no fallback artifacts.
