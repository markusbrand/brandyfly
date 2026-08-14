---
description: "Implement tasks from an OpenSpec change (Experimental)"
---

> **Authoritative store: GitHub issues.** OpenSpec change state for this repository lives in GitHub issues — one issue per change, discovered by the `openspec` label — and no longer in per-change Markdown under `openspec/changes/`. Read and write change state through the repository adapter `tools/openspec-issue/openspec-issue.sh` (contract: `tools/openspec-issue/CONTRACT.md`). The adapter uses `gh` and fails explicitly when GitHub is unavailable, unauthenticated, or lacks permission; there is no local Markdown fallback. Never create per-change directories or Markdown artifacts for change state. Durable capability specs remain source-controlled under `openspec/specs/`.

Implement tasks from an OpenSpec change.

**Input**: Optionally specify a change name (e.g., `/opsx-apply add-auth`). If omitted, check if it can be inferred from conversation context. If vague or ambiguous you MUST prompt for available changes.

**Adapter contract**
- Use `tools/openspec-issue/openspec-issue.sh` for all change-state reads and writes.
- Run `preflight` before listing, finding, or reading. Run `preflight --write` before setting lifecycle or updating sections.
- If GitHub connectivity, auth, or permission fails, stop with the adapter error. Do not create local fallback artifacts.

**Steps**

1. **Select the change**

   If a name is provided, use `find <name>`. Otherwise infer from context, auto-select if only one open change exists, or run:
   ```bash
   tools/openspec-issue/openspec-issue.sh preflight
   tools/openspec-issue/openspec-issue.sh list --state open
   ```
   Ask the user to select one when ambiguous. Always announce: "Using change: <name>" and how to override.

2. **Load planning context**

   Resolve the issue and read the managed sections:
   ```bash
   tools/openspec-issue/openspec-issue.sh find "<name>"
   tools/openspec-issue/openspec-issue.sh get-section <issue> proposal
   tools/openspec-issue/openspec-issue.sh get-section <issue> requirements
   tools/openspec-issue/openspec-issue.sh get-section <issue> design
   tools/openspec-issue/openspec-issue.sh get-section <issue> tasks
   tools/openspec-issue/openspec-issue.sh get-section <issue> verification
   ```

   If the `tasks` section is missing or empty, show a blocked message and suggest `/opsx-continue`.

3. **Enter implementation lifecycle through valid transitions**

   The adapter enforces the lifecycle graph `proposed -> ready -> implementing -> completed`
   and refuses `proposed -> implementing` directly. Read the current lifecycle
   (from `list`/`validate`) and advance only through allowed steps:

   - **implementing** → already implementing; continue.
   - **ready** → promote to implementing:
     ```bash
     tools/openspec-issue/openspec-issue.sh preflight --write
     tools/openspec-issue/openspec-issue.sh set-lifecycle <issue> implementing
     tools/openspec-issue/openspec-issue.sh validate <issue>
     ```
   - **proposed** → only if the change is **ready** (see readiness check),
     promote `proposed -> ready -> implementing`:
     ```bash
     tools/openspec-issue/openspec-issue.sh preflight --write
     tools/openspec-issue/openspec-issue.sh set-lifecycle <issue> ready
     tools/openspec-issue/openspec-issue.sh set-lifecycle <issue> implementing
     tools/openspec-issue/openspec-issue.sh validate <issue>
     ```
     If not ready, STOP and suggest `/opsx-continue`.
   - **completed** → closed/archived; refuse to apply.

   **Readiness check:** the `proposal`, `requirements`, `design`, and `tasks`
   sections must all be present and non-empty and the `tasks` section must have
   at least one `- [ ]`/`- [x]` item. If planning is incomplete, do not
   transition — route to `/opsx-continue`.

4. **Show current progress**

   Parse checkbox tasks in the `tasks` section:
   - `- [ ]` incomplete
   - `- [x]` complete

   Display progress, remaining tasks, and any relevant requirements/design context.

5. **Implement tasks (loop until done or blocked)**

   For each pending task:
   - Show which task is being worked on.
   - Make minimal, focused code changes.
   - Run the smallest targeted verification that proves the task.
   - Update the tasks section: `- [ ]` → `- [x]`.
   - Add verification evidence to the `verification` section, including command, result, and relevant notes.
   - Write both sections before moving on:
     ```bash
     tools/openspec-issue/openspec-issue.sh set-section <issue> tasks --body-file <tasks-file>
     tools/openspec-issue/openspec-issue.sh set-section <issue> verification --body-file <verification-file>
     tools/openspec-issue/openspec-issue.sh validate <issue>
     ```
   - Continue to the next task only after the task is implemented, verified, and recorded in the issue.

   **Pause if:**
   - Task is unclear → ask for clarification.
   - Implementation reveals a design issue → suggest `/opsx-update`.
   - Verification fails or blocker encountered → report and wait for guidance.
   - User interrupts.

6. **On completion or pause, show status**

   Display:
   - Tasks completed this session
   - Overall progress: "N/M tasks complete"
   - If all done: suggest `/opsx-verify` or `/opsx-archive`
   - If paused: explain why and wait for guidance

**Output During Implementation**

```markdown
## Implementing: <change-name> (issue #<issue>)

Working on task 3/7: <task description>
[...implementation happening...]
✓ Task complete; verification recorded in the issue
```

**Output On Completion**

```markdown
## Implementation Complete

**Change:** <change-name>
**Issue:** #<issue>
**Progress:** 7/7 tasks complete ✓

All tasks complete! You can verify or archive this change with `/opsx-verify` or `/opsx-archive`.
```

**Guardrails**
- Keep going through tasks until done or blocked.
- Always read issue sections before starting.
- If a task is ambiguous, pause and ask before implementing.
- If implementation reveals issues, pause and suggest planning updates.
- Keep code changes minimal and scoped to each task.
- Update task checkbox and verification evidence immediately after completing each task.
- Pause on errors, blockers, unclear requirements, or failed verification.
- Use adapter sections; do not assume local planning file names.
- Never create a per-change directory or Markdown artifact under `openspec/changes/`; change state lives only in GitHub issues via the adapter.
