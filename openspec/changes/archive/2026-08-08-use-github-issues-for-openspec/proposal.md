## Why

Repository-local Markdown change artifacts duplicate project-management state, add planning noise to code reviews, and can drift from the GitHub issue used to track implementation. GitHub issues should be the single source of truth for every OpenSpec change so planning, progress, verification evidence, and completion state remain visible and current in one place.

## What Changes

- **BREAKING** Replace repository-local `openspec/changes/<change>/` Markdown artifacts with one GitHub issue per OpenSpec change.
- Define a structured issue format that preserves proposal, requirements, design decisions, implementation tasks, verification evidence, and unresolved limitations.
- Update all OpenSpec creation, continuation, update, apply, verification, listing, synchronization, and archive workflows to read and write the authoritative GitHub issue.
- Require implementation workflows to update issue task progress and verification evidence as work is completed.
- Map OpenSpec lifecycle state to GitHub issue state and labels, including closing the issue only after successful verification/archive.
- Migrate every current open change to an open issue and every archived change to a closed issue, then remove their repository-local Markdown artifacts.
- Fail clearly when GitHub authentication, repository resolution, permissions, issue data, or expected issue structure is unavailable; do not silently fall back to local Markdown.
- Preserve repository-local OpenSpec configuration and durable capability specs where they define framework/project behavior rather than individual change state.
- Non-goals: changing BrandyFly product behavior, storing private flight data in issues, or replacing source-controlled durable capability specifications with GitHub issues.

## Capabilities

### New Capabilities

- `github-issue-change-management`: Defines GitHub-issue-backed creation, discovery, mutation, lifecycle, migration, and failure behavior for OpenSpec changes.

### Modified Capabilities

None.

## Impact

- Affects all repository OpenSpec skills, prompts, and agent guidance under `.github/`, plus OpenSpec configuration and change discovery conventions.
- Introduces GitHub CLI/API access, authentication, repository permissions, labels, and issue templates/structured bodies as workflow dependencies.
- Migrates all existing open and archived change records to GitHub issues and removes their checked-in per-change Markdown files.
- Keeps durable specs under `openspec/specs/` in source control while eliminating repository-local change artifacts after migration.
- Privacy impact: issue content must exclude secrets and private flight data and must respect repository visibility.
- Safety/offline impact: no flight runtime behavior changes; change-management operations require GitHub connectivity and must report offline/unavailable states explicitly.
- Licensing impact: no application dependency or data-license change; migrated issue content retains existing attribution and licensing notes.
