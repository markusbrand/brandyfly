---
id: SPEC-CONTINUOUS-VALIDATION
type: sub-spec
parent: EPIC-01-CORE
title: Continuous Validation
issue_number: 134
status: closed
labels:
  - spec
  - openspec
---

# continuous-validation Specification

## Purpose
Defines automated evidence that specifications, source modules, and deployable
artifacts remain valid across the supported development and runtime targets.
## Requirements
### Requirement: Pull request validation
The repository SHALL run specification, mobile, flight-core, backend, and
container checks on pull requests that affect their corresponding inputs.

#### Scenario: Pull request changes a subsystem
- **WHEN** a pull request changes a validated subsystem or its dependencies
- **THEN** the corresponding automated checks report success or failure before merge

### Requirement: Strict specification validation
The repository SHALL validate all OpenSpec changes and baseline specifications
in strict mode.

#### Scenario: Specification is malformed
- **WHEN** a change contains a malformed requirement or scenario
- **THEN** continuous validation fails with the OpenSpec validation error

### Requirement: Production container validation
The backend production image SHALL build for Linux ARM64 and SHALL run as a
non-root user with a health endpoint.

#### Scenario: ARM64 image is inspected
- **WHEN** continuous validation builds the production backend image for Linux ARM64
- **THEN** the image build succeeds and its configured runtime user is not root

### Requirement: Secret-free automation
Validation SHALL not embed credentials, signing keys, private flight data, or
provider tokens in source, logs, caches, or build artifacts.

#### Scenario: Untrusted pull request is validated
- **WHEN** validation runs for a pull request without repository secrets
- **THEN** all mandatory checks execute using public or synthetic test inputs
