---
name: openspec-new-change
description: Start a new OpenSpec change using the experimental artifact workflow. Use when the user wants to create a new feature, fix, or modification with a structured step-by-step approach.
allowed-tools: Bash(tools/openspec-issue/openspec-issue.sh:*), Bash(gh:*), Bash(npx:*), Bash(openspec:*)
license: MIT
compatibility: Requires the tools/openspec-issue GitHub-issue adapter and the gh CLI; openspec CLI (via npx) is used only for durable-spec validation.
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.8.0"
---

> **Authoritative store: GitHub issues.** OpenSpec change state for this repository lives in GitHub issues — one issue per change, discovered by the `openspec` label — and no longer in per-change Markdown under `openspec/changes/`. Read and write change state through the repository adapter `tools/openspec-issue/openspec-issue.sh` (contract: `tools/openspec-issue/CONTRACT.md`). The adapter uses `gh` and fails explicitly when GitHub is unavailable, unauthenticated, or lacks permission; there is no local Markdown fallback. Never create per-change directories or Markdown artifacts for change state. Durable capability specs remain source-controlled under `openspec/specs/`.

Start a new change using the GitHub-issue-backed OpenSpec workflow.
**Adapter rule:** Use `tools/openspec-issue/openspec-issue.sh` for all change-state reads and writes. Run `tools/openspec-issue/openspec-issue.sh preflight` before reading change state and `tools/openspec-issue/openspec-issue.sh preflight --write` before any create, section update, lifecycle update, or verification recording. If preflight or any adapter command fails because GitHub is unreachable, unauthenticated, or lacks permission, stop and report the explicit failure. Do not create any local fallback artifact.

**Input**: The user's request should include a change name (kebab-case) OR a description of what they want to build.

**Steps**

1. **Clarify the change**
   - If no clear input is provided, ask what they want to build or fix.
   - Derive a kebab-case change name from the request.
   - If the name is invalid, ask for a valid kebab-case name.

2. **Check GitHub-backed change state**
   ```bash
   tools/openspec-issue/openspec-issue.sh preflight --write
   tools/openspec-issue/openspec-issue.sh list --state open
   tools/openspec-issue/openspec-issue.sh find "<name>"
   ```
   If `find` resolves an issue, do not create another change; suggest continuing that issue instead.

3. **Determine schema metadata**
   Use `spec-driven` unless the user explicitly requests a different schema. Store the schema only in the issue metadata; do not create `.openspec.yaml` or a change directory.

4. **Create the issue container**
   Build transient command-input files for metadata and any initial section content, then render and create the managed issue body:
   ```bash
   tools/openspec-issue/openspec-issue.sh render-body --meta <meta.json> --proposal <proposal.md> --requirements <requirements.md> --design <design.md> --tasks <tasks.md> --verification <verification.md> > <body.md>
   tools/openspec-issue/openspec-issue.sh scan-content --body-file <body.md>
   tools/openspec-issue/openspec-issue.sh create --name "<name>" --title "<title>" --schema "<schema>" --lifecycle proposed --body-file <body.md>
   tools/openspec-issue/openspec-issue.sh validate <issue>
   ```
   Transient files are only adapter inputs; remove them after success and never treat them as change state.

5. **Show first-artifact guidance**
   Explain that the issue now holds empty managed sections: `proposal`, `requirements`, `design`, `tasks`, and `verification`. The next step is to draft the proposal section and save it with:
   ```bash
   tools/openspec-issue/openspec-issue.sh set-section <issue> proposal --body-file <proposal.md>
   tools/openspec-issue/openspec-issue.sh validate <issue>
   ```

**Output**

Summarize:
- Change name and GitHub issue number
- Schema metadata
- Current lifecycle (`proposed`)
- The first section to create (`proposal`)
- Prompt: "Ready to draft the proposal? Describe the change and I'll capture it in the issue."

**Guardrails**
- Do not create proposal, requirements, design, or tasks content unless the user asks.
- Never create a per-change directory or Markdown artifact under `openspec/changes/`; change state lives only in the GitHub issue created via the adapter.
- Durable capability specs under `openspec/specs/` are not edited in this workflow.
