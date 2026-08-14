---
description: "Propose a new change - create it and generate all artifacts in one step"
---

> **Authoritative store: GitHub issues.** OpenSpec change state for this repository lives in GitHub issues — one issue per change, discovered by the `openspec` label — and no longer in per-change Markdown under `openspec/changes/`. Read and write change state through the repository adapter `tools/openspec-issue/openspec-issue.sh` (contract: `tools/openspec-issue/CONTRACT.md`). The adapter uses `gh` and fails explicitly when GitHub is unavailable, unauthenticated, or lacks permission; there is no local Markdown fallback. Never create per-change directories or Markdown artifacts for change state. Durable capability specs remain source-controlled under `openspec/specs/`.

Propose a new change - create the GitHub issue-backed change and generate all planning sections in one step.

**Planning boundary**: This workflow creates planning artifacts only. The user request that selected or triggered this workflow authorizes planning only, even if it asks to build or fix something. Do not edit project code. After the planning sections are complete, stop. Do not start implementation in the same response, even if the initial request asks for it. Wait for a new user request after the artifacts are presented; then start the apply workflow.

With the default spec-driven flow, create these managed issue sections:
- `proposal` (what & why)
- `requirements` (delta requirements for durable specs under `openspec/specs/`)
- `design` (how)
- `tasks` (implementation steps)
- `verification` (initially empty or noting "not yet implemented")

`<capability-path>` is the spec directory relative to `openspec/specs/` (for example, `user-auth` or `identity/user-auth`). Preserve an existing capability's full path and follow the project's established organization for new capabilities.

**Adapter contract**
- Use `tools/openspec-issue/openspec-issue.sh` for all change-state reads and writes.
- Run `preflight` before reads and `preflight --write` before creating or updating issue state.
- If GitHub connectivity, auth, or permission checks fail, stop with the adapter error and create no local fallback artifacts.

**Input**: The argument after `/opsx-propose` is the change name (kebab-case), OR a description of what the user wants to build.

**Steps**

1. **Understand the request and clarify material ambiguity**

   If no input is provided, ask the user (open-ended, no preset options):
   > "What change do you want to work on? Describe what you want to build or fix."

   From their description, derive a kebab-case name (e.g., "add user authentication" → `add-user-auth`).

   If the request contains ambiguity that would materially affect scope, externally observable behavior, compatibility, or acceptance criteria, ask before creating the change. For minor details, make a reasonable assumption and record it in the planning sections.

2. **Create or refuse duplicate change**

   ```bash
   tools/openspec-issue/openspec-issue.sh preflight --write
   tools/openspec-issue/openspec-issue.sh find "<name>"
   ```

   If the change exists, ask whether to continue it or choose a new name. If it does not exist, continue.

3. **Draft all planning sections**

   Draft:
   - `proposal`: Why, What Changes, Capabilities, Impact.
   - `requirements`: delta requirements using `## ADDED/MODIFIED/REMOVED/RENAMED Requirements` headings as appropriate.
   - `design`: context, goals/non-goals, decisions, risks.
   - `tasks`: checkbox implementation plan.
   - `verification`: "Not implemented yet" or known validation expectations.

   Apply project context and existing durable specs under `openspec/specs/`, but do not write durable specs during this planning workflow.

4. **Render and create the managed issue body**

   Use the adapter to build and create the issue:
   ```bash
   tools/openspec-issue/openspec-issue.sh render-body --meta <metadata-file> --proposal <proposal-file> --requirements <requirements-file> --design <design-file> --tasks <tasks-file> --verification <verification-file> > <rendered-body-file>
   tools/openspec-issue/openspec-issue.sh create --name "<name>" --title "<title>" --schema spec-driven --lifecycle proposed --body-file <rendered-body-file>
   tools/openspec-issue/openspec-issue.sh validate <issue>
   ```

5. **Mark ready when planning is complete**

   If proposal, requirements, design, and tasks are complete enough for implementation:
   ```bash
   tools/openspec-issue/openspec-issue.sh set-lifecycle <issue> ready
   tools/openspec-issue/openspec-issue.sh validate <issue>
   ```

6. **Show final status**

   Use `tools/openspec-issue/openspec-issue.sh get-section <issue> <section>` as needed to summarize what was created.

**Output**

After completing all sections, summarize:
- Change name and GitHub issue number
- List of sections created with brief descriptions
- What's ready: "All planning sections needed for implementation are ready."
- Prompt: "The artifacts are ready for review. When you are ready, run `/opsx-apply`."

**Guardrails**
- Planning only: do not implement, start apply, or edit project code.
- Ask about ambiguities that would materially change scope; make reasonable assumptions for minor details and record them.
- If a change with that name already exists, ask if the user wants to continue it or create a new one.
- Validate the issue after every mutation.
- Never create a per-change directory or Markdown artifact under `openspec/changes/`; change state lives only in GitHub issues via the adapter.
