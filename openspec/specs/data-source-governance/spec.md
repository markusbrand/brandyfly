---
id: SPEC-DATA-SOURCE-GOVERNANCE
type: sub-spec
parent: EPIC-01-CORE
title: Data Source Governance
issue_number: 16
status: closed
labels:
  - spec
  - openspec
---

# data-source-governance Specification

## Purpose

Defines the evidence and lifecycle controls required before third-party data can
be consumed, cached, displayed, or redistributed by BrandyFly.

## Requirements

### Requirement: Every data category has an explicit decision
The audit SHALL inventory candidates for base maps, elevation and hillshade,
airspace, geocoding, live pilots, and thermal-derived data and classify each
candidate as approved, rejected, or blocked.

#### Scenario: Category has no approved provider
- **WHEN** every candidate for a required category is rejected or blocked
- **THEN** dependent implementation remains blocked and no undocumented substitute is used

### Requirement: Decisions are traceable to authoritative evidence
Each provider decision SHALL record provider identity, dataset, authoritative
terms URL or written permission, evidence date, reviewer, attribution,
redistribution, caching, derivation, retention, rate-limit, privacy, and update
constraints.

#### Scenario: Candidate is approved
- **WHEN** a candidate is marked approved
- **THEN** all applicable evidence fields are complete and no mandatory term is based solely on an observed undocumented endpoint

#### Scenario: Terms are ambiguous
- **WHEN** a mandatory use such as offline redistribution is not explicitly permitted
- **THEN** the candidate is marked blocked until clarification is recorded

### Requirement: Packages expose provenance and attribution
Every generated data-package manifest SHALL include dataset identifier, provider,
source version or date, build time, license identifier or terms URL,
attribution text and URL, geographic coverage, checksum, and review expiry.

#### Scenario: Manifest metadata is incomplete
- **WHEN** a package lacks any mandatory provenance or attribution field
- **THEN** publication is rejected before the package becomes downloadable

### Requirement: Approval expires safely
Each approved source SHALL have a revalidation date and documented response for
provider unavailability, stale data, changed terms, and revoked permission.

#### Scenario: Review expires
- **WHEN** the revalidation date passes without renewed evidence
- **THEN** new package publication is blocked while already installed data remains labelled with its source date

#### Scenario: Redistribution permission is revoked
- **WHEN** authoritative evidence shows that redistribution is no longer allowed
- **THEN** new downloads are disabled and the incident procedure identifies affected versions without deleting users' only offline data during flight

### Requirement: Personal data use is minimised
Candidates containing pilot or precise location data SHALL document legal basis,
consent expectations, data fields, retention, deletion, and onward-sharing
limits before approval.

#### Scenario: Privacy obligations are unknown
- **WHEN** a live-data provider does not document the rights required for BrandyFly's intended use
- **THEN** the candidate remains blocked and no real user data is collected for evaluation
