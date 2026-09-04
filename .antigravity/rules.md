# OpenSpec Two-Tier Hierarchical Workflow Rules

## 1. Two-Tier Hierarchy (Epics -> Sub-Specs)
- **Major Initiatives Start with an Epic**:
  - Every major architectural initiative, subsystem redesign, or multi-feature capability MUST start with an Epic specification (`type: epic`).
  - Epics follow the schema template defined in `openspec/schemas/epic-schema.md`.
  - Epics define overarching purpose, high-level scope, boundary constraints, and a checklist of child sub-specs.
- **Granular Tasks/Features are Sub-Specs**:
  - Detailed features, interfaces, refactors, and technical tasks are broken down into Sub-Specs (`type: sub-spec`).
  - Sub-specs follow the schema template defined in `openspec/schemas/subspec-schema.md`.
  - Every Sub-Spec MUST reference its parent Epic via the YAML frontmatter field `parent: <EPIC_ID>` (e.g. `parent: EPIC-01-CORE`).

## 2. Single Source of Truth
- **Repository Markdown Files are Authoritative**:
  - All requirements, scopes, acceptance criteria, task lists, and issue linkages live directly in version-controlled Markdown files under `openspec/specs/**`.
  - Do NOT manage task state or issue hierarchy out-of-band.

## 3. Lifecycle & Progress Tracking
- **Frontmatter Status Updates**:
  - The AI agent MUST keep the YAML frontmatter `status` field up-to-date during the lifecycle of an initiative:
    `open` -> `in_progress` -> `review` -> `closed`
- **Task Checkboxes**:
  - The agent MUST check off task checkboxes (`- [x]`) as implementation tasks and acceptance criteria are completed and verified.

## 4. GitHub Synchronization & Tooling Boundary
- **Do Not Execute Manual GitHub Issue Commands in the IDE**:
  - Do NOT manually run `gh issue create`, `gh issue edit`, or `gh issue close` directly from the IDE or development session.
  - Synchronization between local OpenSpec Markdown specifications and GitHub Issues (including native GitHub Sub-issues linking and tasklist updates) is handled automatically via the central GitHub Actions workflow (`.github/workflows/openspec-sync.yml`).
