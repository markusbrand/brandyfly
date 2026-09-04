---
id: EPIC-01-CORE
type: epic
title: Core Monorepo and Flight Pipeline Architecture
issue_number: 133
status: closed
labels:
  - epic
  - openspec
---

# Core Monorepo and Flight Pipeline Architecture

## Purpose

Defines the core monorepo foundation, native Rust flight pipeline, hardware sensor
transports, offline data governance, and flight computer display subsystem.

## Requirements

### Requirement: Foundational architecture and modularity
The application SHALL organize domain logic, native flight pipelines, hardware transports,
and mapping subsystems behind distinct, verifiable boundaries.

#### Scenario: Core subsystem boundary verification
- **WHEN** all core specifications and modules are inspected
- **THEN** each foundational subsystem has an unambiguous specification, clear boundaries, and isolated tests

## Sub-Specs
- [x] `SPEC-CONTINUOUS-VALIDATION` - Continuous Validation
- [x] `SPEC-REPOSITORY-FOUNDATION` - Repository Foundation
- [x] `SPEC-NATIVE-FLIGHT-PIPELINE` - Native Flight Pipeline Validation
- [x] `SPEC-SKYDROP1-TRANSPORT` - SkyDrop 1 Transport Validation
- [x] `SPEC-FLIGHT-TRACKING-REPLAY` - Flight Tracking Logbook and Replay
- [x] `SPEC-DATA-SOURCE-GOVERNANCE` - Data Source Governance
- [x] `SPEC-SCREEN-WIDGET-CONFIGURATION` - Screen Widget Configuration
- [x] `SPEC-THERMALING-LIFT-SINK-MAP` - Thermaling Screen Lift-Sink Map
- [x] `SPEC-XCONTEST-INTEGRATION` - XContest Integration Readiness
