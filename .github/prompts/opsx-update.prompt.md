---
description: "Update a change - revise existing planning artifacts and keep them coherent (Experimental)"
---

> **Authoritative store: GitHub issues.** OpenSpec change state for this repository lives in GitHub issues — one issue per change, discovered by the `openspec` label — and no longer in per-change Markdown under `openspec/changes/`. Read and write change state through the repository adapter `tools/openspec-issue/openspec-issue.sh` (contract: `tools/openspec-issue/CONTRACT.md`). The adapter uses `gh` and fails explicitly when GitHub is unavailable, unauthenticated, or lacks permission; there is no local Markdown fallback. Never create per-change directories or Markdown artifacts for change state. Durable capability specs remain source-controlled under `openspec/specs/`.

Revise a change's existing planning sections and keep them coherent. Never edit code.

**Input**: Optionally specify a change name after `/opsx-update` (e.g., `/opsx-update add-auth`). If omitted, check if it can be inferred from conversation context. If vague or ambiguous you MUST prompt for available changes.

**Adapter contract**
- Use `tools/openspec-issue/openspec-issue.sh` for all change-state reads and writes.
- Run `preflight` before listing, finding, or reading. Run `preflight --write` before any `set-section` or `set-lifecycle`.
- If GitHub connectivity, auth, or permission fails, stop with the adapter error and create no local fallback artifact.

**Steps**

1. **Select the change**

   If a name is provided, use `find <name>`. Otherwise infer from context, auto-select if only one open change exists, or run:
   ```bash
   tools/openspec-issue/openspec-issue.sh list --state open
   ```
   Ask the user to select when ambiguous. Show name, issue number, lifecycle, state, and task progress. Mark the most recently active change as "(Recommended)" when known.

2. **Read the change's sections**

   ```bash
   tools/openspec-issue/openspec-issue.sh preflight
   tools/openspec-issue/openspec-issue.sh get-section <issue> proposal
   tools/openspec-issue/openspec-issue.sh get-section <issue> requirements
   tools/openspec-issue/openspec-issue.sh get-section <issue> design
   tools/openspec-issue/openspec-issue.sh get-section <issue> tasks
   tools/openspec-issue/openspec-issue.sh get-section <issue> verification
   ```

   Use these managed issue sections as the authoritative planning artifacts. Durable capability specs under `openspec/specs/` are source-controlled reference material, not change state.

3. **Understand the request**
   - If the user asked for a specific revision, that is the starting edit.
   - If they only said "update" or "make this coherent", do a coherence review across the existing issue sections for contradictions, gaps, and duplication.

4. **Read and reconcile**
   - Read the sections the request touches and all other existing sections.
   - Apply the requested edit. Then check every other section against it in any direction: a later-section edit may require revising an earlier section.
   - Note everything that is inconsistent, missing, or contradictory.
   - Revise only existing sections unless the user asks to create a missing section; point to `/opsx-continue` for normal missing-section creation.
   - If the change is already coherent, say so and make no edits.

5. **Confirm and apply, one section at a time**
   - Show each proposed revision and why. Write only after the user confirms.
   - If the user rejects a revision, leave that section unchanged.
   - For each accepted revision:
     ```bash
     tools/openspec-issue/openspec-issue.sh preflight --write
     tools/openspec-issue/openspec-issue.sh set-section <issue> <section> --body-file <section-file>
     tools/openspec-issue/openspec-issue.sh validate <issue>
     ```

6. **Point to the next step (guidance only - NEVER act on it)**
   - Sections still missing -> suggest `/opsx-continue`.
   - Change already implemented -> suggest `/opsx-apply` to carry revised planning into code.
   - Everything done and implemented -> suggest `/opsx-archive`.

**Output**

After each invocation, show:
- Which sections were revised (and which proposed revisions were rejected)
- Anything deferred to `/opsx-continue`
- Where the change stands and the recommended next command

**Guardrails**
- Planning sections only - NEVER edit implementation code.
- Use adapter-managed sections; never branch on local file names.
- Confirm every edit with the user before writing.
- If the request changes the change's intent rather than refining it, recommend starting fresh with `/opsx-new` and a distinct unused change name.
- Never create a per-change directory or Markdown artifact under `openspec/changes/`; change state lives only in GitHub issues via the adapter.
