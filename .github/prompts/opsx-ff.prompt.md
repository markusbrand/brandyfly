---
description: "Create a change and generate all artifacts needed for implementation in one go"
---

> **Authoritative store: GitHub issues.** OpenSpec change state for this repository lives in GitHub issues — one issue per change, discovered by the `openspec` label — and no longer in per-change Markdown under `openspec/changes/`. Read and write change state through the repository adapter `tools/openspec-issue/openspec-issue.sh` (contract: `tools/openspec-issue/CONTRACT.md`). The adapter uses `gh` and fails explicitly when GitHub is unavailable, unauthenticated, or lacks permission; there is no local Markdown fallback. Never create per-change directories or Markdown artifacts for change state. Durable capability specs remain source-controlled under `openspec/specs/`.

Fast-forward through artifact creation - generate everything needed to start implementation in one GitHub issue-backed change.

**Input**: The argument after `/opsx-ff` is the change name (kebab-case), OR a description of what the user wants to build.

**Adapter contract**
- Use `tools/openspec-issue/openspec-issue.sh` for all change-state reads and writes.
- Run `preflight --write` before creating or updating issue state.
- If GitHub is unavailable, unauthenticated, or lacks permission, stop and report the adapter failure. Do not create a local fallback artifact.

**Steps**

1. **If no input provided, ask what they want to build**

   Ask the user (open-ended, no preset options):
   > "What change do you want to work on? Describe what you want to build or fix."

   From their description, derive a kebab-case name (e.g., "add user authentication" → `add-user-auth`).

2. **Create the issue-backed change**

   ```bash
   tools/openspec-issue/openspec-issue.sh preflight --write
   tools/openspec-issue/openspec-issue.sh find "<name>"
   ```

   If it exists, ask whether to continue it or pick a new name. If it is absent, create it by building the full managed body via `render-body` and then running:
   ```bash
   tools/openspec-issue/openspec-issue.sh create --name "<name>" --title "<title>" --schema spec-driven --lifecycle proposed --body-file <rendered-body-file>
   tools/openspec-issue/openspec-issue.sh validate <issue>
   ```

3. **Create every planning section needed for implementation**

   Use a todo list to track sections in dependency order:
   1. `proposal`
   2. `requirements`
   3. `design` (skip only when clearly unnecessary; record why)
   4. `tasks`
   5. `verification` (initial expectations or "not yet implemented")

   For each section:
   - Read completed dependency sections with `get-section <issue> <section>`.
   - Draft content using the schema conventions.
   - Write with `set-section <issue> <section> --body-file <section-file>`.
   - Run `validate <issue>` immediately after writing.
   - Show brief progress: "✓ Created <section>".

4. **Mark the change ready**

   When required sections are complete:
   ```bash
   tools/openspec-issue/openspec-issue.sh set-lifecycle <issue> ready
   tools/openspec-issue/openspec-issue.sh validate <issue>
   ```

5. **Validate durable specs**

   If this workflow touched durable specs (normally it should not), validate them with:
   ```bash
   npx --yes @fission-ai/openspec@latest validate --all --strict
   ```
   This validates source-controlled durable specs under `openspec/specs/`, not change state.

**Output**

After completing all planning sections, summarize:
- Change name and GitHub issue number
- List of sections created with brief descriptions, plus any conditional section you skipped and why
- What's ready: "All artifacts needed for implementation are ready."
- Prompt: "Run `/opsx-apply` to start implementing."

**Guardrails**
- Create every section the apply phase depends on.
- Always read dependency sections before creating a new one.
- If context is critically unclear, ask the user; otherwise make reasonable decisions to keep momentum.
- If a change with that name already exists, ask if the user wants to continue it or create a new one.
- Validate the issue after each section update.
- Never create a per-change directory or Markdown artifact under `openspec/changes/`; change state lives only in GitHub issues via the adapter.
