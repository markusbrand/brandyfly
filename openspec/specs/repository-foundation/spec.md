---
id: SPEC-REPOSITORY-FOUNDATION
type: sub-spec
parent: EPIC-01-CORE
title: Repository Foundation
issue_number: 21
status: closed
labels:
  - spec
  - openspec
---

# repository-foundation Specification

## Purpose
Defines a reproducible public workspace in which mobile, flight-core, native,
backend, and data-pipeline changes can evolve behind explicit module boundaries.
## Requirements
### Requirement: Supported source modules
The repository SHALL provide distinct source roots for the mobile application,
shared flight core, native platform integration, backend service, and map
pipeline.

#### Scenario: Developer locates a subsystem
- **WHEN** a developer checks out the repository
- **THEN** each supported subsystem has one documented source root and owner boundary

### Requirement: Independent module validation
Each executable or library module SHALL expose a documented command that checks
its formatting, static analysis, and tests without requiring production secrets.

#### Scenario: Developer validates a clean checkout
- **WHEN** the documented prerequisites are installed and validation commands run
- **THEN** every implemented module completes validation without private credentials

### Requirement: Public licensing
The repository source SHALL be distributed under the MIT License and SHALL
distinguish third-party data attribution from source-code licensing.

#### Scenario: User reviews licensing
- **WHEN** a user opens the repository licensing documentation
- **THEN** the source license and the requirement to inspect dataset-specific attribution are clear

### Requirement: Agent-readable change workflow
The repository SHALL provide OpenSpec workflows for Antigravity proposal,
implementation, verification, synchronization, and archival activities.

#### Scenario: Agent starts a feature
- **WHEN** an Antigravity agent receives a non-trivial feature request
- **THEN** it can discover repository-local OpenSpec instructions before editing source code
