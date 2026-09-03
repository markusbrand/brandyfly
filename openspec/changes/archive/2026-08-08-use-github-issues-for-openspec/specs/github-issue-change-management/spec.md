## Purpose

Defines how OpenSpec changes are represented, discovered, updated, verified, migrated, and completed when GitHub issues are the authoritative change store.

## ADDED Requirements

### Requirement: One authoritative issue per change
The OpenSpec workflow SHALL represent each change with exactly one GitHub issue in the current repository, identified by an OpenSpec label and stable machine-readable change metadata.

#### Scenario: Create a change
- **WHEN** a user starts a new OpenSpec change with a unique kebab-case name
- **THEN** the workflow creates one open GitHub issue containing that name, schema, lifecycle state, proposal, requirements, design, tasks, and verification sections
- **AND** the workflow does not create a repository-local per-change Markdown artifact

#### Scenario: Duplicate change name
- **WHEN** an open or closed OpenSpec issue already contains the requested stable change name
- **THEN** the workflow refuses to create another issue
- **AND** reports the existing issue reference

### Requirement: Structured issue content
The authoritative issue SHALL preserve human-readable OpenSpec artifacts in stable, independently updateable sections while retaining user-authored content outside managed sections.

#### Scenario: Update one artifact
- **WHEN** a workflow updates a proposal, requirements, design, tasks, or verification artifact
- **THEN** it fetches the latest issue body and replaces only the corresponding managed section
- **AND** preserves all other managed sections and user-authored content

#### Scenario: Malformed issue content
- **WHEN** an issue is labeled as OpenSpec but lacks valid stable metadata or required managed section boundaries
- **THEN** the workflow stops without rewriting the issue
- **AND** reports the malformed or missing content

### Requirement: Issue-backed discovery and status
OpenSpec listing, selection, and status workflows SHALL derive change identity, lifecycle state, and artifact completion from GitHub issues rather than from `openspec/changes/`.

#### Scenario: List open changes
- **WHEN** a user requests all open OpenSpec changes
- **THEN** the workflow lists open issues carrying the OpenSpec label
- **AND** reports each issue number, change name, lifecycle state, and artifact progress

#### Scenario: GitHub state changes outside the workflow
- **WHEN** an issue or its labels were changed after a previous workflow read
- **THEN** the next operation uses the latest GitHub state
- **AND** does not restore stale repository-local state

### Requirement: Implementation progress updates
The apply workflow SHALL update the authoritative issue as implementation tasks and validation steps complete.

#### Scenario: Complete an implementation task
- **WHEN** an implementation task is verified as complete
- **THEN** the apply workflow marks the corresponding issue task complete
- **AND** records relevant validation evidence in the issue before proceeding

#### Scenario: Implementation is interrupted
- **WHEN** implementation stops before all tasks complete
- **THEN** completed issue tasks remain marked complete
- **AND** incomplete tasks remain open so a later workflow can resume from GitHub state

### Requirement: Verified completion and archival
The archive workflow SHALL close an OpenSpec issue only after required tasks and verification are complete, while synchronizing accepted durable requirements into repository capability specs.

#### Scenario: Archive a verified change
- **WHEN** all required tasks are complete and verification succeeds
- **THEN** accepted requirement deltas are synchronized to durable specs under `openspec/specs/`
- **AND** verification evidence and unresolved limitations are recorded in the issue
- **AND** the issue is labeled completed and closed

#### Scenario: Archive an incomplete change
- **WHEN** required tasks or verification evidence are incomplete
- **THEN** the workflow leaves the issue open
- **AND** reports every completion prerequisite that is not satisfied

### Requirement: Existing change migration
Migration SHALL create one issue for every existing open and archived repository-local change before removing its per-change files.

#### Scenario: Migrate an open change
- **WHEN** an existing change is active
- **THEN** migration creates an open issue preserving all proposal, requirement, design, and task content and completion state
- **AND** removes the repository-local change directory only after validating the issue content

#### Scenario: Migrate an archived change
- **WHEN** an existing change is archived
- **THEN** migration creates a closed completed issue preserving its artifacts, verification evidence, archive date, and unresolved limitations
- **AND** removes the repository-local archived change directory only after validating the issue content

#### Scenario: Migration write fails
- **WHEN** issue creation or validation fails for a change
- **THEN** migration retains that change's repository-local artifacts
- **AND** reports the failure without treating the change as migrated

### Requirement: Explicit GitHub failure behavior
Issue-backed OpenSpec operations SHALL fail clearly when GitHub is unavailable, authentication is invalid, repository resolution fails, or permissions are insufficient, and SHALL NOT silently use local Markdown as a fallback.

#### Scenario: Operation is attempted offline
- **WHEN** GitHub cannot be reached during an issue-backed operation
- **THEN** the workflow makes no success claim or local change artifact
- **AND** reports that connectivity is required

#### Scenario: Write permission is missing
- **WHEN** authenticated GitHub access can read but cannot create or update the required issue
- **THEN** the workflow leaves existing issue content unchanged
- **AND** reports the missing permission and failed operation

### Requirement: Sensitive content protection
OpenSpec issue workflows SHALL exclude secrets and private flight data from issue content and SHALL respect the repository's visibility boundary.

#### Scenario: Sensitive content is detected
- **WHEN** proposed issue content contains a credential, secret, or private flight record
- **THEN** the workflow refuses to publish that content
- **AND** identifies the category of content that must be removed without echoing the sensitive value
