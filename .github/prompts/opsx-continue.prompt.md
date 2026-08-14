---
description: "Continue working on a change - create the next artifact (Experimental)"
---

> **Authoritative store: GitHub issues.** OpenSpec change state for this repository lives in GitHub issues — one issue per change, discovered by the `openspec` label — and no longer in per-change Markdown under `openspec/changes/`. Read and write change state through the repository adapter `tools/openspec-issue/openspec-issue.sh` (contract: `tools/openspec-issue/CONTRACT.md`). The adapter uses `gh` and fails explicitly when GitHub is unavailable, unauthenticated, or lacks permission; there is no local Markdown fallback. Never create per-change directories or Markdown artifacts for change state. Durable capability specs remain source-controlled under `openspec/specs/`.

Continue working on a change by creating the next missing GitHub issue section.

**Input**: Optionally specify a change name after `/opsx-continue` (e.g., `/opsx-continue add-auth`). If omitted, check if it can be inferred from conversation context. If vague or ambiguous you MUST prompt for available changes.

**Adapter contract**
- Use `tools/openspec-issue/openspec-issue.sh` for all change-state reads and writes.
- Run `preflight` before listing or reading and `preflight --write` before writing.
- If GitHub connectivity, auth, or permission fails, stop with the adapter error. Do not create local fallback artifacts.

**Steps**

1. **Select the change**

   If a name is provided, resolve it:
   ```bash
   tools/openspec-issue/openspec-issue.sh preflight
   tools/openspec-issue/openspec-issue.sh find "<name>"
   ```

   Otherwise infer from context, auto-select if only one open change exists, or list choices:
   ```bash
   tools/openspec-issue/openspec-issue.sh list --state open
   ```

   When prompting, present the top 3-4 active changes with name, lifecycle, issue state, and task progress. Always announce: "Using change: <name>" and how to override.

2. **Check current section status**

   Read sections:
   ```bash
   tools/openspec-issue/openspec-issue.sh get-section <issue> proposal
   tools/openspec-issue/openspec-issue.sh get-section <issue> requirements
   tools/openspec-issue/openspec-issue.sh get-section <issue> design
   tools/openspec-issue/openspec-issue.sh get-section <issue> tasks
   tools/openspec-issue/openspec-issue.sh get-section <issue> verification
   ```

   Treat an empty or placeholder section as not done. Planning is complete when `proposal`, `requirements`, and `tasks` are done; `design` may be skipped only when explicitly unnecessary and noted.

3. **Act based on status**

   **If planning is complete:**
   - Congratulate the user.
   - If lifecycle is still `proposed`, run `preflight --write`, `set-lifecycle <issue> ready`, then `validate <issue>`.
   - Suggest `/opsx-apply` and STOP.

   **If a section is ready to create:**
   - Pick the first missing section in order: `proposal`, `requirements`, `design`, `tasks`, `verification`.
   - Read dependency sections using `get-section`.
   - Draft the section using the schema conventions.
   - Write it:
     ```bash
     tools/openspec-issue/openspec-issue.sh preflight --write
     tools/openspec-issue/openspec-issue.sh set-section <issue> <section> --body-file <section-file>
     tools/openspec-issue/openspec-issue.sh validate <issue>
     ```
   - STOP after creating ONE section.

   **If no section can be created because context is unclear:**
   - Ask the user for the missing decision.

4. **After creating a section, show progress**

   Summarize which sections are done and what section is next.

**Output**

After each invocation, show:
- Which section was created
- Current progress (N/M planning sections complete)
- What is now unlocked
- Prompt: "Run `/opsx-continue` to create the next artifact"

**Artifact Creation Guidelines**
- The issue section ids are `proposal`, `requirements`, `design`, `tasks`, and `verification`.
- Read dependency sections before creating a new section.
- Apply project context and durable specs under `openspec/specs/` as constraints, but do not copy unrelated context into the issue.

**Guardrails**
- Create ONE section per invocation.
- Never skip required sections or create out of order unless the user explicitly accepts the skip and the reason is recorded.
- If context is unclear, ask before creating.
- Validate the issue after writing.
- Use the adapter's issue sections; do not assume local artifact file names.
- Never create a per-change directory or Markdown artifact under `openspec/changes/`; change state lives only in GitHub issues via the adapter.
