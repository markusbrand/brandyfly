---
description: "Start a new change using the experimental artifact workflow (OPSX)"
---

> **Authoritative store: GitHub issues.** OpenSpec change state for this repository lives in GitHub issues — one issue per change, discovered by the `openspec` label — and no longer in per-change Markdown under `openspec/changes/`. Read and write change state through the repository adapter `tools/openspec-issue/openspec-issue.sh` (contract: `tools/openspec-issue/CONTRACT.md`). The adapter uses `gh` and fails explicitly when GitHub is unavailable, unauthenticated, or lacks permission; there is no local Markdown fallback. Never create per-change directories or Markdown artifacts for change state. Durable capability specs remain source-controlled under `openspec/specs/`.

Start a new change using the experimental artifact-driven approach.

**Input**: The argument after `/opsx-new` is the change name (kebab-case), OR a description of what the user wants to build.

**Adapter contract**
- Use `tools/openspec-issue/openspec-issue.sh` for all change-state reads and writes.
- Run `tools/openspec-issue/openspec-issue.sh preflight` before reading change state and `tools/openspec-issue/openspec-issue.sh preflight --write` before creating or updating an issue.
- If preflight, `find`, `create`, `set-section`, or `validate` fails because GitHub is unavailable, unauthenticated, or lacks permission, stop and report the explicit failure. Do not create any local fallback artifact.

**Steps**

1. **If no input provided, ask what they want to build**

   Ask the user (open-ended, no preset options):
   > "What change do you want to work on? Describe what you want to build or fix."

   From their description, derive a kebab-case name (e.g., "add user authentication" → `add-user-auth`).

   **IMPORTANT**: Do NOT proceed without understanding what the user wants to build.

2. **Determine the workflow schema**

   Use the repository's default OpenSpec workflow, which stores issue sections named `proposal`, `requirements`, `design`, `tasks`, and `verification`. If the user explicitly asks for a different schema, explain that this GitHub-issue-backed prompt only manages the adapter's standard section set unless the adapter contract is extended.

3. **Create the GitHub issue-backed change**

   Run:
   ```bash
   tools/openspec-issue/openspec-issue.sh preflight --write
   tools/openspec-issue/openspec-issue.sh find "<name>"
   ```

   If `find` succeeds, the change already exists; suggest `/opsx-continue <name>` instead. If it exits with the adapter's not-found status, create an issue:

   1. Draft an initial proposal stub and empty `requirements`, `design`, `tasks`, and `verification` section files as transient inputs.
   2. Build the full managed issue body with `tools/openspec-issue/openspec-issue.sh render-body --meta <metadata-file> --proposal <proposal-file> --requirements <requirements-file> --design <design-file> --tasks <tasks-file> --verification <verification-file>`.
   3. Create the issue with `tools/openspec-issue/openspec-issue.sh create --name "<name>" --title "<title>" --schema spec-driven --lifecycle proposed --body-file <rendered-body-file>`.
   4. Run `tools/openspec-issue/openspec-issue.sh validate <issue>`.

4. **Show the artifact status**

   Read current sections with:
   ```bash
   tools/openspec-issue/openspec-issue.sh get-section <issue> proposal
   tools/openspec-issue/openspec-issue.sh get-section <issue> requirements
   tools/openspec-issue/openspec-issue.sh get-section <issue> design
   tools/openspec-issue/openspec-issue.sh get-section <issue> tasks
   tools/openspec-issue/openspec-issue.sh get-section <issue> verification
   ```

   Treat empty sections as not yet created. The first artifact is usually `proposal`.

5. **Show instructions for the first artifact**

   Present the expected `proposal` shape (`Why`, `What Changes`, `Impact`) and remind the user that later sections are stored in the same GitHub issue.

6. **STOP and wait for user direction**

**Output**

After completing the steps, summarize:
- Change name and GitHub issue number
- Schema/section sequence (`proposal` → `requirements` → `design` → `tasks` → `verification`)
- Current status (0/4 planning sections complete)
- The template for the first artifact
- Prompt: "Ready to create the first artifact? Run `/opsx-continue` or just describe what this change is about and I'll draft it."

**Guardrails**
- Do NOT create planning sections beyond the initial scaffold unless the user asked for them.
- Do NOT advance beyond showing the first artifact template.
- If the name is invalid (not kebab-case), ask for a valid name.
- If a change with that name already exists, suggest using `/opsx-continue` instead.
- Never create a per-change directory or Markdown artifact under `openspec/changes/`; change state lives only in the GitHub issue created via the adapter.
