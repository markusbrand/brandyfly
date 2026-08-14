---
description: "Verify implementation matches change artifacts before archiving"
---

> **Authoritative store: GitHub issues.** OpenSpec change state for this repository lives in GitHub issues — one issue per change, discovered by the `openspec` label — and no longer in per-change Markdown under `openspec/changes/`. Read and write change state through the repository adapter `tools/openspec-issue/openspec-issue.sh` (contract: `tools/openspec-issue/CONTRACT.md`). The adapter uses `gh` and fails explicitly when GitHub is unavailable, unauthenticated, or lacks permission; there is no local Markdown fallback. Never create per-change directories or Markdown artifacts for change state. Durable capability specs remain source-controlled under `openspec/specs/`.

Verify that an implementation matches the GitHub issue-backed change sections (requirements, tasks, design) before completing it.

**Input**: Optionally specify a change name after `/opsx-verify` (e.g., `/opsx-verify add-auth`). If omitted, check if it can be inferred from conversation context. If vague or ambiguous you MUST prompt for available changes.

**Adapter contract**
- Use `tools/openspec-issue/openspec-issue.sh` for all change-state reads and writes.
- Run `preflight` before listing/finding/reading. Run `preflight --write` before writing the verification section.
- If GitHub connectivity, auth, or permission fails, stop with the adapter error. Do not create local fallback artifacts.

**Steps**

1. **Select the change**

   If a name is provided, use `find <name>`. Otherwise infer from context, auto-select if only one open change exists, or run:
   ```bash
   tools/openspec-issue/openspec-issue.sh preflight
   tools/openspec-issue/openspec-issue.sh list --state open
   ```
   When prompting, prefer changes that have implementation tasks. Include lifecycle and task progress if available.

2. **Load planning sections**

   ```bash
   tools/openspec-issue/openspec-issue.sh get-section <issue> proposal
   tools/openspec-issue/openspec-issue.sh get-section <issue> requirements
   tools/openspec-issue/openspec-issue.sh get-section <issue> design
   tools/openspec-issue/openspec-issue.sh get-section <issue> tasks
   tools/openspec-issue/openspec-issue.sh get-section <issue> verification
   ```

3. **Initialize verification report structure**

   Create a report with three dimensions:
   - **Completeness**: task and requirement coverage
   - **Correctness**: requirement implementation and scenario coverage
   - **Coherence**: design adherence and pattern consistency

   Each dimension can have CRITICAL, WARNING, or SUGGESTION issues.

4. **Verify Completeness**

   **Task Completion**:
   - Parse task checkboxes in the `tasks` section: `- [ ]` vs `- [x]`.
   - Add a CRITICAL issue for each incomplete task.

   **Requirement Coverage**:
   - Extract requirements from the `requirements` section.
   - Search the codebase for implementation evidence and tests.
   - Add CRITICAL issues for apparently unimplemented requirements.

5. **Verify Correctness**

   For each requirement and scenario:
   - Search codebase for implementation evidence.
   - Note file paths and line ranges when found.
   - Add WARNING issues when implementation appears to diverge from the requirement or scenario.

6. **Verify Coherence**

   - If the `design` section exists, verify implementation follows key decisions.
   - Review new code for significant consistency issues with project patterns.
   - Prefer SUGGESTION for uncertain or minor issues.

7. **Validate durable specs when relevant**

   If durable specs under `openspec/specs/` were changed or are part of the verification, run:
   ```bash
   npx --yes @fission-ai/openspec@latest validate --all --strict
   ```
   This validates source-controlled durable specs, not GitHub issue change state.

8. **Write verification evidence to the issue**

   Generate the report and save it:
   ```bash
   tools/openspec-issue/openspec-issue.sh preflight --write
   tools/openspec-issue/openspec-issue.sh set-section <issue> verification --body-file <verification-file>
   tools/openspec-issue/openspec-issue.sh validate <issue>
   ```

**Output Format**

Use clear markdown with:
- Table for summary scorecard
- Grouped lists for issues (CRITICAL/WARNING/SUGGESTION)
- Code references in format: `file.ts:123`
- Specific, actionable recommendations
- No vague suggestions like "consider reviewing"

**Final Assessment**
- If CRITICAL issues: "X critical issue(s) found. Fix before archiving."
- If only warnings: "No critical issues. Y warning(s) to consider. Ready for archive (with noted improvements)."
- If all clear: "All checks passed. Ready for archive."

**Guardrails**
- Focus on objective checklist items and requirement evidence.
- Use reasonable inference; don't require perfect certainty.
- When uncertain, prefer SUGGESTION over WARNING, WARNING over CRITICAL.
- Every issue must have a specific recommendation with file/line references where applicable.
- Always record verification output in the issue before reporting completion.
- Never create a per-change directory or Markdown artifact under `openspec/changes/`; change state lives only in GitHub issues via the adapter.
