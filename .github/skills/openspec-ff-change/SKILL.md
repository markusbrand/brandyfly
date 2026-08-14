---
name: openspec-ff-change
description: Fast-forward through OpenSpec artifact creation. Use when the user wants to quickly create all artifacts needed for implementation without stepping through each one individually.
allowed-tools: Bash(tools/openspec-issue/openspec-issue.sh:*), Bash(gh:*), Bash(npx:*), Bash(openspec:*)
license: MIT
compatibility: Requires the tools/openspec-issue GitHub-issue adapter and the gh CLI; openspec CLI (via npx) is used only for durable-spec validation.
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.8.0"
---

> **Authoritative store: GitHub issues.** OpenSpec change state for this repository lives in GitHub issues — one issue per change, discovered by the `openspec` label — and no longer in per-change Markdown under `openspec/changes/`. Read and write change state through the repository adapter `tools/openspec-issue/openspec-issue.sh` (contract: `tools/openspec-issue/CONTRACT.md`). The adapter uses `gh` and fails explicitly when GitHub is unavailable, unauthenticated, or lacks permission; there is no local Markdown fallback. Never create per-change directories or Markdown artifacts for change state. Durable capability specs remain source-controlled under `openspec/specs/`.

Fast-forward through planning section creation so a change becomes ready for implementation.
**Adapter rule:** Use `tools/openspec-issue/openspec-issue.sh` for all change-state reads and writes. Run `tools/openspec-issue/openspec-issue.sh preflight` before reading change state and `tools/openspec-issue/openspec-issue.sh preflight --write` before any create, section update, lifecycle update, or verification recording. If preflight or any adapter command fails because GitHub is unreachable, unauthenticated, or lacks permission, stop and report the explicit failure. Do not create any local fallback artifact.

**Input**: A change name (kebab-case) OR a description of what to build.

**Steps**

1. **Clarify and name the change**
   - Ask for missing intent only when the request is unclear.
   - Derive a kebab-case name and issue title.
   - Use `spec-driven` schema metadata unless explicitly told otherwise.

2. **Create or resolve the issue**
   ```bash
   tools/openspec-issue/openspec-issue.sh preflight --write
   tools/openspec-issue/openspec-issue.sh find "<name>"
   ```
   If no issue exists, create it with `render-body` and `create --lifecycle proposed`. If an issue exists, use that issue and read existing sections with `get-section` before writing anything.

3. **Build the required section set**
   For the default spec-driven workflow, the apply phase needs `proposal`, `requirements`, `design` when warranted, and `tasks`. Custom schemas must still be represented in the managed issue sections; do not create schema files or local artifact paths.

4. **Fill missing sections in dependency order**
   - Read dependency sections from the issue with `get-section` immediately before using them.
   - Draft each missing section using the schema intent.
   - Write each section with:
     ```bash
     tools/openspec-issue/openspec-issue.sh set-section <issue> <proposal|requirements|design|tasks|verification> --body-file <section.md>
     tools/openspec-issue/openspec-issue.sh validate <issue>
     ```
   - Use `verification` to record assumptions, skipped optional design rationale, and readiness notes.

5. **Mark the change ready**
   After the required planning sections are complete:
   ```bash
   tools/openspec-issue/openspec-issue.sh set-lifecycle <issue> ready
   tools/openspec-issue/openspec-issue.sh validate <issue>
   ```

**Output**

Summarize:
- Change name and issue number
- Sections created or reused
- Any optional section deliberately skipped and why
- "All sections needed for implementation are ready."
- Prompt: "Run `/opsx-apply` or ask me to implement to start working on the tasks."

**Guardrails**
- Create every section apply depends on, not just tasks.
- Re-read issue sections before deriving dependent content.
- Never create or verify files under a change directory; the issue is authoritative.
- If an adapter command fails, stop without creating local fallback content.
