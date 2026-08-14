---
name: openspec-continue-change
description: Continue working on an OpenSpec change by creating the next artifact. Use when the user wants to progress their change, create the next artifact, or continue their workflow.
allowed-tools: Bash(tools/openspec-issue/openspec-issue.sh:*), Bash(gh:*), Bash(npx:*), Bash(openspec:*)
license: MIT
compatibility: Requires the tools/openspec-issue GitHub-issue adapter and the gh CLI; openspec CLI (via npx) is used only for durable-spec validation.
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.8.0"
---

> **Authoritative store: GitHub issues.** OpenSpec change state for this repository lives in GitHub issues — one issue per change, discovered by the `openspec` label — and no longer in per-change Markdown under `openspec/changes/`. Read and write change state through the repository adapter `tools/openspec-issue/openspec-issue.sh` (contract: `tools/openspec-issue/CONTRACT.md`). The adapter uses `gh` and fails explicitly when GitHub is unavailable, unauthenticated, or lacks permission; there is no local Markdown fallback. Never create per-change directories or Markdown artifacts for change state. Durable capability specs remain source-controlled under `openspec/specs/`.

Continue a GitHub-issue-backed OpenSpec change by creating the next missing section.
**Adapter rule:** Use `tools/openspec-issue/openspec-issue.sh` for all change-state reads and writes. Run `tools/openspec-issue/openspec-issue.sh preflight` before reading change state and `tools/openspec-issue/openspec-issue.sh preflight --write` before any create, section update, lifecycle update, or verification recording. If preflight or any adapter command fails because GitHub is unreachable, unauthenticated, or lacks permission, stop and report the explicit failure. Do not create any local fallback artifact.

**Input**: Optionally specify a change name. If omitted, infer from context only when unambiguous; otherwise list open changes and ask the user to select one.

**Steps**

1. **Select the change**
   ```bash
   tools/openspec-issue/openspec-issue.sh preflight
   tools/openspec-issue/openspec-issue.sh list --state open
   tools/openspec-issue/openspec-issue.sh find "<name>"
   ```
   Present the most relevant open changes with name, issue number, lifecycle, state, and task progress from the adapter list output.

2. **Read current sections**
   ```bash
   tools/openspec-issue/openspec-issue.sh get-section <issue> proposal
   tools/openspec-issue/openspec-issue.sh get-section <issue> requirements
   tools/openspec-issue/openspec-issue.sh get-section <issue> design
   tools/openspec-issue/openspec-issue.sh get-section <issue> tasks
   tools/openspec-issue/openspec-issue.sh get-section <issue> verification
   ```
   Use issue metadata from `read <issue>` only for schema/lifecycle context.

3. **Choose the next section**
   - If `proposal` is empty, draft proposal.
   - Else if `requirements` is empty and requirements are needed, draft delta requirements.
   - Else if `design` is empty and design is warranted, draft design; otherwise record in `verification` why design is skipped.
   - Else if `tasks` is empty, draft tasks.
   - If all planning sections needed for apply exist, set lifecycle to `ready` after write preflight.

4. **Write exactly one section**
   Before writing:
   ```bash
   tools/openspec-issue/openspec-issue.sh preflight --write
   ```
   Then:
   ```bash
   tools/openspec-issue/openspec-issue.sh set-section <issue> <section> --body-file <section.md>
   tools/openspec-issue/openspec-issue.sh validate <issue>
   ```
   If this completes the planning set:
   ```bash
   tools/openspec-issue/openspec-issue.sh set-lifecycle <issue> ready
   tools/openspec-issue/openspec-issue.sh validate <issue>
   ```

**Output**

Show:
- Which section was created
- Schema/lifecycle context
- Current progress through proposal → requirements → design → tasks
- What is now unlocked
- Prompt: "Want to continue? Ask me to continue or tell me what to do next."

**Guardrails**
- Create one section per invocation.
- Never skip required planning content silently.
- Read dependency sections from the issue, not from conversation memory.
- Never write per-change local artifacts; change state lives in the issue.
- Stop explicitly on GitHub/auth/permission failures.
