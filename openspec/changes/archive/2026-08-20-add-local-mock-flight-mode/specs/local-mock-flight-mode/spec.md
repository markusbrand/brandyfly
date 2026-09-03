## Purpose

Define a deterministic, development-only test mode that exercises BrandyFly
end-to-end with synthetic flight data and mocked integrations on a laptop.

## ADDED Requirements

### Requirement: Mock flight mode is development-only
The system SHALL expose local mock flight mode only in development/test builds
and MUST reject activation in production build profiles.

#### Scenario: Developer enables mock mode
- **WHEN** a development build starts with mock mode enabled
- **THEN** the app boots with mock providers active and marks the session as simulated

#### Scenario: Production build attempts mock mode
- **WHEN** a production build is started with any mock-mode activation flag
- **THEN** startup fails closed for mock mode and continues only with live-mode configuration

### Requirement: Replay is deterministic and reproducible
The system SHALL produce identical event timelines for the same fixture version,
seed, logical clock step, and scenario configuration across supported
development platforms.

#### Scenario: Same replay inputs are reused
- **WHEN** two runs execute the same scenario fixture, seed, and clock configuration
- **THEN** both runs emit the same ordered event hash and identical high-level flight state transitions

#### Scenario: Replay inputs differ
- **WHEN** fixture version, seed, or clock configuration changes
- **THEN** the run metadata records the changed inputs and resulting event hash for traceable comparison

### Requirement: End-to-end features run without live external inputs
In mock mode, the system SHALL satisfy app feature dependencies through local
synthetic providers and mocked interfaces without requiring network connectivity
or physical flight sensors.

#### Scenario: Laptop is offline
- **WHEN** mock mode runs with all network routes disabled
- **THEN** map, telemetry views, logs, alerts, and upload/export flows complete using configured mock responses

#### Scenario: Live interfaces are unavailable
- **WHEN** live GNSS, vario, or remote APIs are absent during mock mode
- **THEN** no feature regresses to hard failure solely due to missing live inputs

### Requirement: Stale and failure behavior is explicit and testable
Mock scenarios SHALL support scripted stale data, delayed responses, dropped
updates, and hard errors, and the app SHALL surface each state with observable
status and recovery behavior.

#### Scenario: Telemetry becomes stale
- **WHEN** a scenario injects telemetry older than the stale threshold
- **THEN** the UI and logs indicate stale state within 1 second and recovery clears the stale indicator after fresh data resumes

#### Scenario: External dependency fails
- **WHEN** a scenario injects timeout or error responses from a mocked external interface
- **THEN** the app records a structured error, shows degraded state, and continues other unaffected features

### Requirement: Privacy and safety boundaries are enforced
Synthetic fixtures and outputs SHALL exclude private pilot identifiers and MUST
clearly distinguish simulated sessions from live-flight evidence.

#### Scenario: Fixture provenance is checked
- **WHEN** fixtures are loaded for mock mode
- **THEN** metadata confirms synthetic/anonymized source and run startup is blocked if required provenance fields are missing

#### Scenario: Simulated data is viewed or exported
- **WHEN** a user views or exports data from mock mode
- **THEN** persistent simulation labeling is present and exported artifacts include a machine-readable simulated-session marker
