---
description: "Sync delta specs from a change to main specs"
---

> **Authoritative store: GitHub issues.** OpenSpec change state for this repository lives in GitHub issues — one issue per change, discovered by the `openspec` label — and no longer in per-change Markdown under `openspec/changes/`. Read and write change state through the repository adapter `tools/openspec-issue/openspec-issue.sh` (contract: `tools/openspec-issue/CONTRACT.md`). The adapter uses `gh` and fails explicitly when GitHub is unavailable, unauthenticated, or lacks permission; there is no local Markdown fallback. Never create per-change directories or Markdown artifacts for change state. Durable capability specs remain source-controlled under `openspec/specs/`.

Sync accepted requirement deltas from a GitHub issue-backed change into durable specs under `openspec/specs/`.

This is an **agent-driven** operation - you will read the change's `requirements` section and directly edit durable main specs to apply the changes. This allows intelligent merging (e.g., adding a scenario without copying an entire requirement).

`<capability-path>` is the spec directory relative to `openspec/specs/` (for example, `user-auth` or `identity/user-auth`). Preserve the full path from each delta requirement when resolving its main spec.

**Input**: Optionally specify a change name after `/opsx-sync` (e.g., `/opsx-sync add-auth`). If omitted, check if it can be inferred from conversation context. If vague or ambiguous you MUST prompt for available changes.

**Adapter contract**
- Use `tools/openspec-issue/openspec-issue.sh` to read and update change state.
- Run `preflight` before listing/finding/reading and `preflight --write` before recording verification evidence.
- If GitHub connectivity, auth, or permission fails, stop with the adapter error. Do not create local fallback artifacts.
- Durable spec validation uses `npx --yes @fission-ai/openspec@latest validate --all --strict`; it validates source-controlled specs under `openspec/specs/`, not issue change state.

**Steps**

1. **Select the change**

   If a name is provided, use `find <name>`. Otherwise infer from context, auto-select if only one open change exists, or run:
   ```bash
   tools/openspec-issue/openspec-issue.sh preflight
   tools/openspec-issue/openspec-issue.sh list --state open
   ```
   Ask the user to select one when ambiguous. Prefer changes whose `requirements` section contains delta requirement headings.

2. **Read delta requirements**

   ```bash
   tools/openspec-issue/openspec-issue.sh get-section <issue> requirements
   ```

   Treat the `requirements` section as the only source of change deltas. If it is empty or has no delta requirements, report that there are no deltas to sync and stop without writing durable specs.

3. **Identify affected durable specs**

   Parse the `requirements` section for capability paths and delta headings:
   - `## ADDED Requirements`
   - `## MODIFIED Requirements`
   - `## REMOVED Requirements`
   - `## RENAMED Requirements`

   Every delta MUST carry an explicit `<capability-path>`. If the section does
   not explicitly name a capability path for a delta, do NOT infer, guess, or
   assume one, and do NOT mutate any durable spec. Instead stop and either:
   - report that there is nothing safe to sync (when no path is given), or
   - ask the user to confirm a concrete `<capability-path>` and proceed only with
     that user-confirmed path.
   Never write to a spec based on a guessed path.

4. **For each capability delta, apply changes to durable main specs**

   a. **Read the delta content** from the issue section.

   b. **Read the main spec** at `openspec/specs/<capability-path>/spec.md` (may not exist yet).

   c. **Apply changes intelligently**:

      **ADDED Requirements:**
      - If the requirement does not exist in the main spec → add it.
      - If it already exists → update it to match (treat as implicit MODIFIED).

      **MODIFIED Requirements:**
      - Find the requirement in the main spec.
      - Apply changes, preserving scenarios/content not mentioned in the delta.

      **REMOVED Requirements:**
      - Remove the named requirement block.
      - Delete the durable spec file only when removal leaves no requirements and the change clearly retires the capability; otherwise stop and ask for clarification rather than leaving an empty `## Requirements` section.

      **RENAMED Requirements:**
      - Find the FROM requirement and rename it to TO.

      **`## Purpose` in the delta:**
      - If the main spec already has a Purpose, leave it authoritative.
      - For a new spec, seed Purpose from the delta or use a brief TBD placeholder and report it.

   d. **Create a new main spec** if capability does not exist yet:
      - Create `openspec/specs/<capability-path>/spec.md`.
      - Add `## Purpose` and `## Requirements` sections.
      - Follow the Main Spec Format Reference below.

5. **Validate updated durable specs**

   Run:
   ```bash
   npx --yes @fission-ai/openspec@latest validate --all --strict
   ```
   If validation fails, report the problems and do not claim the sync succeeded.

6. **Record verification evidence in the issue**

   Append a sync record to the `verification` section with affected specs and validation output, then write it:
   ```bash
   tools/openspec-issue/openspec-issue.sh preflight --write
   tools/openspec-issue/openspec-issue.sh set-section <issue> verification --body-file <verification-file>
   tools/openspec-issue/openspec-issue.sh validate <issue>
   ```

7. **Show summary**

   Summarize capabilities updated, changes made, validation result, and any TBD Purpose placeholders.

**Delta Requirement Format Reference**

```markdown
## ADDED Requirements

### Requirement: New Feature
The system SHALL do something new.

#### Scenario: Basic case
- **WHEN** user does X
- **THEN** system does Y

## MODIFIED Requirements

### Requirement: Existing Feature
The system SHALL keep doing the existing thing, now also handling A.

#### Scenario: New scenario to add
- **WHEN** user does A
- **THEN** system does B

## REMOVED Requirements

### Requirement: Deprecated Feature

## RENAMED Requirements

- FROM: `### Requirement: Old Name`
- TO: `### Requirement: New Name`
```

**Main Spec Format Reference**

Durable main specs must never contain delta operation headers after syncing:

```markdown
# <capability> Specification

## Purpose
Short description of what this capability does and why it exists.

## Requirements

### Requirement: New Feature
The system SHALL do something new.

#### Scenario: Basic case
- **WHEN** user does X
- **THEN** system does Y
```

**Guardrails**
- Read both issue requirements and durable main specs before making changes.
- Preserve existing durable spec content not mentioned in the delta.
- Never copy a delta wholesale into a main spec; merge it into the durable main spec format.
- Never infer, guess, or assume a `<capability-path>`. Require an explicit path in
  the issue requirements or a concrete user-confirmed path; otherwise stop without
  mutating any spec.
- If something is unclear, ask for clarification.
- The operation should be idempotent.
- Validate durable specs after writing.
- Record sync validation evidence in the issue.
- Never create a per-change directory or Markdown artifact under `openspec/changes/`; change state lives only in GitHub issues via the adapter.
