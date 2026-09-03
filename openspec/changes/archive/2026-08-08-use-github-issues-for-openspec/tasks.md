## 1. Issue Contract and Shared Operations

- [x] 1.1 Define the versioned issue metadata, managed-section markers, lifecycle labels, and valid state transitions in one reusable repository-owned OpenSpec integration surface.
- [x] 1.2 Implement reusable `gh`-based operations for repository/auth checks, unique change lookup, issue creation, latest-body reads, section-preserving updates, label/state updates, and post-write validation without local Markdown fallback.
- [x] 1.3 Add sensitive-content, malformed-schema, duplicate-name, connectivity, permission, body-size, and partial-write error handling that preserves the last valid source state.
- [x] 1.4 Validate the shared operations with fixture-backed checks covering issue round trips, unmanaged-text preservation, duplicate/malformed issues, interrupted updates, and explicit GitHub failures.

## 2. Planning and Discovery Workflows

- [x] 2.1 Update new, propose, fast-forward, continue, update, explore, and onboarding skills/prompts to create and mutate managed sections in one authoritative GitHub issue.
- [x] 2.2 Update list, show, selection, status, and agent guidance to discover issues by OpenSpec label and report issue number, stable change name, lifecycle, and artifact/task progress from current GitHub state.
- [x] 2.3 Update repository contributor/development documentation and OpenSpec configuration guidance to distinguish issue-backed change state from source-controlled durable capability specs.
- [x] 2.4 Validate every planning/discovery workflow against temporary test issues, including duplicate creation, stale reads, human text preservation, malformed issue refusal, and offline/authentication failure behavior.

## 3. Implementation and Completion Workflows

- [x] 3.1 Update apply behavior to read tasks from the issue, set the implementing lifecycle, and persist each verified task plus validation evidence before moving to the next task.
- [x] 3.2 Update sync behavior to apply issue-hosted requirement deltas to `openspec/specs/` while retaining the issue as the active change source of truth.
- [x] 3.3 Update verification behavior to compare implementation, durable specs, and issue-hosted artifacts and to write structured evidence and unresolved limitations back to the issue.
- [x] 3.4 Update single and bulk archive behavior to enforce completion prerequisites, synchronize accepted specs, mark completed lifecycle state, and close issues without creating archive directories.
- [x] 3.5 Validate apply resume after interruption, sync idempotency, verification failure, incomplete archive refusal, successful archive, and bulk partial-failure reporting with temporary test issues.

## 4. Existing Change Migration

- [x] 4.1 Inventory every active and archived local change, including this migration change, and generate dry-run issue payloads that preserve metadata, proposal, delta requirements, design, task completion, verification evidence, archive dates, and unresolved limitations.
- [x] 4.2 Review dry-run payloads for secrets, private flight data, GitHub body limits, duplicate stable names, required sections, and correct intended open/closed state before publishing.
- [x] 4.3 Create and post-write validate one open issue for each active change and one closed completed issue for each archived change, recording the change-name-to-issue-number mapping and leaving failed items untouched.
- [x] 4.4 Validate migration idempotency by rerunning discovery/dry-run checks and confirming no duplicate issues or content drift are produced.

## 5. Repository Cutover

- [x] 5.1 Remove each successfully migrated active and archived per-change directory, including this temporary planning directory, while preserving `openspec/config.yaml` and durable specs under `openspec/specs/`.
- [x] 5.2 Remove or replace all remaining repository instructions and documentation that treat `openspec/changes/` or per-change Markdown as authoritative.
- [x] 5.3 Add a repository validation check that fails when a workflow reintroduces per-change Markdown storage assumptions or a new local change directory.
- [x] 5.4 Validate the cutover with repository-wide searches, OpenSpec durable-spec validation, documentation checks if available, and a clean review of the resulting Git diff.

## 6. End-to-End Acceptance

- [x] 6.1 Exercise create, propose, continue, update, list, show, apply-resume, sync, verify, archive, and bulk-archive flows end to end against GitHub issues.
- [x] 6.2 Verify that GitHub connectivity/authentication/permission failures never create local fallback artifacts or produce success-shaped output.
- [x] 6.3 Verify all migrated issue bodies, labels, task states, and open/closed states against their source artifacts and confirm no secrets or private flight data were published.
- [x] 6.4 Run the smallest existing repository checks covering changed workflow/documentation surfaces and record final verification evidence in the migration issue before closing it.
