---
name: openspec-explore
description: Enter explore mode - a thinking partner for exploring ideas, investigating problems, and clarifying requirements. Use when the user wants to think through something before or during a change.
allowed-tools: Bash(tools/openspec-issue/openspec-issue.sh:*), Bash(gh:*), Bash(npx:*), Bash(openspec:*)
license: MIT
compatibility: Requires the tools/openspec-issue GitHub-issue adapter and the gh CLI; openspec CLI (via npx) is used only for durable-spec validation.
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.8.0"
---

> **Authoritative store: GitHub issues.** OpenSpec change state for this repository lives in GitHub issues — one issue per change, discovered by the `openspec` label — and no longer in per-change Markdown under `openspec/changes/`. Read and write change state through the repository adapter `tools/openspec-issue/openspec-issue.sh` (contract: `tools/openspec-issue/CONTRACT.md`). The adapter uses `gh` and fails explicitly when GitHub is unavailable, unauthenticated, or lacks permission; there is no local Markdown fallback. Never create per-change directories or Markdown artifacts for change state. Durable capability specs remain source-controlled under `openspec/specs/`.

Enter explore mode. Think deeply, investigate freely, and capture decisions only when the user asks.
**Adapter rule:** Use `tools/openspec-issue/openspec-issue.sh` for all change-state reads and writes. Run `tools/openspec-issue/openspec-issue.sh preflight` before reading change state and `tools/openspec-issue/openspec-issue.sh preflight --write` before any create, section update, lifecycle update, or verification recording. If preflight or any adapter command fails because GitHub is unreachable, unauthenticated, or lacks permission, stop and report the explicit failure. Do not create any local fallback artifact.

**IMPORTANT: Explore mode is for thinking, not implementing.** You may read files, search code, and investigate the codebase, but you must never implement features. You may capture OpenSpec planning sections in GitHub issues when the user asks.

---

## The Stance

- **Curious, not prescriptive** - Ask questions that emerge naturally.
- **Open threads, not interrogations** - Surface options and let the user follow what resonates.
- **Visual** - Use ASCII diagrams when they clarify thinking.
- **Adaptive** - Pivot when new information emerges.
- **Grounded** - Explore the actual codebase when relevant.

---

## OpenSpec Awareness

At the start, quickly check GitHub-backed change context:
```bash
tools/openspec-issue/openspec-issue.sh preflight
tools/openspec-issue/openspec-issue.sh list --state open
```
This tells you active changes, lifecycle labels, issue numbers, and task progress. If a change is relevant, resolve it with `find <name>` and read sections with `get-section`.

Read project-level durable context from `openspec/config.yaml` or `openspec/config.yml` when it exists. That file is source-controlled project context, not per-change state.

### When no change exists

Think freely. When insights crystallize, offer:
- "This feels solid enough to start a change. Want me to create a proposal?"
- Or keep exploring without formalizing.

If the user asks to capture exploration as a new change:
1. Run `preflight --write` and check `find <name>`.
2. Build transient metadata and section inputs, then `render-body`, `scan-content`, and `create --name "<name>" --title "<title>" --schema "<schema>" --lifecycle proposed --body-file <body.md>`.
3. Validate the issue.
4. If the user asked for specific sections, write them with `set-section` and `validate`; when the planning set is complete, `set-lifecycle <issue> ready` and validate.

### When a change exists

1. Resolve it:
   ```bash
   tools/openspec-issue/openspec-issue.sh find "<name>"
   ```
2. Read context from managed sections:
   ```bash
   tools/openspec-issue/openspec-issue.sh get-section <issue> proposal
   tools/openspec-issue/openspec-issue.sh get-section <issue> requirements
   tools/openspec-issue/openspec-issue.sh get-section <issue> design
   tools/openspec-issue/openspec-issue.sh get-section <issue> tasks
   tools/openspec-issue/openspec-issue.sh get-section <issue> verification
   ```
3. Reference findings naturally in conversation.
4. Offer to capture decisions. If the user agrees, run `preflight --write`, update the relevant issue section with `set-section`, and validate.

| Insight Type | Section to Capture |
| --- | --- |
| Scope or rationale changed | `proposal` |
| Requirement changed | `requirements` |
| Design decision made | `design` |
| New work identified | `tasks` |
| Evidence or assumptions | `verification` |

---

## Ending Discovery

Discovery might flow into a proposal, update issue sections, or simply provide clarity. Summaries are optional; sometimes the thinking is the value.

---

## Guardrails

- Do not implement code.
- Do not auto-capture; offer and wait for user agreement.
- Never create a per-change directory or Markdown artifact under `openspec/changes/`; use the adapter-created GitHub issue.
- If GitHub access fails, continue discussion if useful but do not claim change state was saved.
- Durable specs under `openspec/specs/` are edited only by sync/archive-style workflows, not casual exploration.
