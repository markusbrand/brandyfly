---
name: openspec-propose
description: Propose a new change with all artifacts generated in one step into an authoritative GitHub issue.
allowed-tools: Bash(openspec:*)
license: MIT
compatibility: Requires gh and openspec-issue adapter.
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.8.0"
---

Propose a new change - create the change and generate all sections (`proposal`, `requirements`, `design`, `tasks`) into an authoritative GitHub issue in one step.

**Planning boundary**: This workflow creates planning artifacts in a GitHub issue only. Do not edit project code until the user authorizes the apply workflow.

**Steps**

1. **Understand the Request & Preflight**
   - Run `./tools/openspec-issue/openspec-issue.sh preflight --write`
   - Derive a kebab-case name (e.g., `rework-screen-widget-settings`).

2. **Draft Complete Content**
   - **Proposal**: Why, What Changes, Capabilities, Non-Goals, Impact.
   - **Requirements**: Delta specs with `### Requirement: ...` (SHALL/MUST) and `#### Scenario: ...` (WHEN/THEN).
   - **Design**: Context, Goals/Non-Goals, Decisions, Risks/Trade-offs, Migration Plan.
   - **Tasks**: Checkbox list `- [ ] X.Y ...` grouped under numbered `##` headers.

3. **Render Body & Scan**
   - Render the managed body using `./tools/openspec-issue/openspec-issue.sh render-body`.
   - Scan for secrets / sensitive flight data using `./tools/openspec-issue/openspec-issue.sh scan-content`.

4. **Create GitHub Issue**
   - Run:
     ```bash
     ./tools/openspec-issue/openspec-issue.sh create --name "<name>" --title "OpenSpec: <name>" --schema spec-driven --lifecycle proposed --body-file <rendered-file>
     ```
   - Transition lifecycle to `ready` if all sections are complete:
     ```bash
     ./tools/openspec-issue/openspec-issue.sh set-lifecycle <issue-number> ready
     ```
   - Never create per-change directories under `openspec/changes/`.
   - Present summary of the created issue to the user.
