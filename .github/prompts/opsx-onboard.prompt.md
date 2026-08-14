---
description: "Guided onboarding - walk through a complete OpenSpec workflow cycle with narration"
---

> **Authoritative store: GitHub issues.** OpenSpec change state for this repository lives in GitHub issues — one issue per change, discovered by the `openspec` label — and no longer in per-change Markdown under `openspec/changes/`. Read and write change state through the repository adapter `tools/openspec-issue/openspec-issue.sh` (contract: `tools/openspec-issue/CONTRACT.md`). The adapter uses `gh` and fails explicitly when GitHub is unavailable, unauthenticated, or lacks permission; there is no local Markdown fallback. Never create per-change directories or Markdown artifacts for change state. Durable capability specs remain source-controlled under `openspec/specs/`.

Guide the user through their first complete OpenSpec workflow cycle. This is a teaching experience—you'll do real work in their codebase while explaining each step.

---

## Preflight

Before starting, check the GitHub issue-backed OpenSpec adapter:

```bash
tools/openspec-issue/openspec-issue.sh preflight
tools/openspec-issue/openspec-issue.sh preflight --write
```

If either command fails because GitHub is unavailable, unauthenticated, or lacks permission, stop and report the adapter failure. There is no local Markdown fallback.

Durable specs are validated with:
```bash
npx --yes @fission-ai/openspec@latest validate --all --strict
```
This validates source-controlled durable specs under `openspec/specs/`, not change state.

---

## Phase 1: Welcome

Display:

```markdown
## Welcome to OpenSpec!

I'll walk you through a complete change cycle—from idea to implementation—using a real task in your codebase. In this repository, each OpenSpec change lives in a GitHub issue managed by `tools/openspec-issue/openspec-issue.sh`.

**What we'll do:**
1. Pick a small, real task in your codebase
2. Explore the problem briefly
3. Create a GitHub issue-backed change
4. Build the issue sections: proposal → requirements → design → tasks
5. Implement the tasks
6. Sync accepted requirements into durable specs and complete the issue

**Time:** ~15-20 minutes

Let's start by finding something to work on.
```

---

## Phase 2: Task Selection

### Codebase Analysis

Scan the codebase for small improvement opportunities. Look for:
1. **TODO/FIXME comments** - Search for `TODO`, `FIXME`, `HACK`, `XXX` in code files
2. **Missing error handling** - `catch` blocks that swallow errors, risky operations without try-catch
3. **Functions without tests** - Cross-reference source with test directories
4. **Type issues** - `any` types in TypeScript files (`: any`, `as any`)
5. **Debug artifacts** - `console.log`, `console.debug`, `debugger` statements in non-debug code
6. **Missing validation** - User input handlers without validation

Also check recent git activity:
```bash
git log --oneline -10 2>/dev/null || echo "No git history"
```

### Present Suggestions

From your analysis, present 3-4 specific suggestions with location, scope, and why each is a good onboarding task. If nothing obvious is found, ask what small thing the user has been meaning to add or fix.

### Scope Guardrail

If the user picks or describes something too large, guide them toward a smaller slice but let them override.

---

## Phase 3: Explore Demo

Once a task is selected, briefly demonstrate explore mode:

```markdown
Before we create a change, let me quickly show you **explore mode**—it's how you think through problems before committing to a direction.
```

Spend 1-2 minutes investigating relevant code, draw a quick ASCII diagram if useful, and note considerations. Then pause for acknowledgment.

---

## Phase 4: Create the Change

**EXPLAIN:**
```markdown
## Creating a Change

A "change" in this repository is a GitHub issue with managed OpenSpec sections. The issue is discovered by the `openspec` label and carries one lifecycle label such as `openspec:proposed` or `openspec:ready`.

Let me create one for our task.
```

**DO:** Create the issue with a derived kebab-case name:
```bash
tools/openspec-issue/openspec-issue.sh preflight --write
tools/openspec-issue/openspec-issue.sh render-body --meta <metadata-file> --proposal <proposal-file> --requirements <requirements-file> --design <design-file> --tasks <tasks-file> --verification <verification-file> > <rendered-body-file>
tools/openspec-issue/openspec-issue.sh create --name "<derived-name>" --title "<title>" --schema spec-driven --lifecycle proposed --body-file <rendered-body-file>
tools/openspec-issue/openspec-issue.sh validate <issue>
```

**SHOW:**
```markdown
Created GitHub issue: #<issue>

Managed sections in the issue:
- proposal      ← Why we're doing this
- requirements  ← Delta requirements
- design        ← How we'll build it
- tasks         ← Implementation checklist
- verification  ← Evidence captured as we work

Now let's fill in the proposal.
```

Never create a per-change directory or Markdown artifact under `openspec/changes/`; change state lives only in the GitHub issue created via the adapter.

---

## Phase 5: Proposal

Draft proposal content with `Why`, `What Changes`, `Capabilities`, and `Impact`. Pause for approval. After approval:

```bash
tools/openspec-issue/openspec-issue.sh preflight --write
tools/openspec-issue/openspec-issue.sh set-section <issue> proposal --body-file <proposal-file>
tools/openspec-issue/openspec-issue.sh validate <issue>
```

Then explain that the proposal can be refined later by updating the issue section.

---

## Phase 6: Requirements

Explain that requirements define **what** is being built in precise, testable terms. Use delta headings such as:

```markdown
## ADDED Requirements

### Requirement: <Name>
<Description of what the system should do>

#### Scenario: <Scenario name>
- **WHEN** <trigger condition>
- **THEN** <expected outcome>
```

`<capability-path>` is the spec directory relative to `openspec/specs/`. Preserve existing capability paths for modifications.

Save with:
```bash
tools/openspec-issue/openspec-issue.sh set-section <issue> requirements --body-file <requirements-file>
tools/openspec-issue/openspec-issue.sh validate <issue>
```

---

## Phase 7: Design

Draft the `design` section with context, goals/non-goals, decisions, and risks. For small changes, keep it brief. Save with:

```bash
tools/openspec-issue/openspec-issue.sh set-section <issue> design --body-file <design-file>
tools/openspec-issue/openspec-issue.sh validate <issue>
```

---

## Phase 8: Tasks

Generate checkbox tasks based on requirements and design:

```markdown
## 1. [Category or file]
- [ ] 1.1 [Specific task]
- [ ] 1.2 [Specific task]

## 2. Verify
- [ ] 2.1 [Verification step]
```

Pause before implementation. Save with:
```bash
tools/openspec-issue/openspec-issue.sh set-section <issue> tasks --body-file <tasks-file>
tools/openspec-issue/openspec-issue.sh set-lifecycle <issue> ready
tools/openspec-issue/openspec-issue.sh validate <issue>
```

---

## Phase 9: Apply (Implementation)

**EXPLAIN:**
```markdown
## Implementation

Now we implement each task, checking them off in the issue as we go. After each task, we record verification evidence before moving on.
```

**DO:**
1. Run `tools/openspec-issue/openspec-issue.sh set-lifecycle <issue> implementing`.
2. Read tasks with `get-section <issue> tasks`.
3. For each pending task:
   - Announce the task.
   - Implement minimal code changes.
   - Run the targeted verification command that proves the task.
   - Update the tasks section (`- [ ]` → `- [x]`) with `set-section <issue> tasks --body-file <tasks-file>`.
   - Append evidence to the `verification` section with `set-section <issue> verification --body-file <verification-file>`.
   - Run `validate <issue>` before starting the next task.

Keep narration light—don't over-explain every line of code.

---

## Phase 10: Complete the Change

**EXPLAIN:**
```markdown
## Completing the Change

When a change is complete, we sync accepted requirement deltas into durable specs under `openspec/specs/`, validate those specs, record evidence, and close the GitHub issue by setting lifecycle `completed`. We do not create an archive directory.
```

**DO:**
1. Read the `requirements` section.
2. Merge accepted deltas into the appropriate durable spec files under `openspec/specs/`.
3. Run `npx --yes @fission-ai/openspec@latest validate --all --strict`.
4. Record verification evidence in the issue's `verification` section.
5. Complete the issue:
   ```bash
   tools/openspec-issue/openspec-issue.sh preflight --write
   tools/openspec-issue/openspec-issue.sh set-section <issue> verification --body-file <verification-file>
   tools/openspec-issue/openspec-issue.sh validate <issue>
   tools/openspec-issue/openspec-issue.sh set-lifecycle <issue> completed
   tools/openspec-issue/openspec-issue.sh validate <issue>
   ```

**SHOW:**
```markdown
Completed GitHub issue: #<issue>
Durable specs validated under `openspec/specs/`.
```

---

## Phase 11: Recap & Next Steps

```markdown
## Congratulations!

You just completed a full OpenSpec cycle:
1. **Explore** - Thought through the problem
2. **New** - Created a GitHub issue-backed change
3. **Proposal** - Captured WHY
4. **Requirements** - Defined WHAT in detail
5. **Design** - Decided HOW
6. **Tasks** - Broke it into steps
7. **Apply** - Implemented the work
8. **Complete** - Synced specs and closed the issue

Try `/opsx-propose` on something you actually want to build. You've got the rhythm now!
```

---

## Graceful Exit Handling

If the user wants to stop mid-way:

```markdown
No problem! Your change is saved in GitHub issue #<issue>.

To pick up where we left off later:
- `/opsx-continue <name>` - Resume planning section creation
- `/opsx-apply <name>` - Jump to implementation once tasks exist

The work won't be lost. Come back whenever you're ready.
```

---

## Guardrails

- **Follow the EXPLAIN → DO → SHOW → PAUSE pattern** at key transitions.
- **Keep narration light** during implementation—teach without lecturing.
- **Don't skip phases** even if the change is small—the goal is teaching the workflow.
- **Pause for acknowledgment** at marked points, but don't over-pause.
- **Handle exits gracefully**—never pressure the user to continue.
- **Use real codebase tasks**—don't simulate or use fake examples.
- **Adjust scope gently**—guide toward smaller tasks but respect user choice.
- **No local fallback**—if the adapter cannot read or write GitHub issue state, stop explicitly.
