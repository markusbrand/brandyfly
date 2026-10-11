# Spec Delta

## Purpose

Calculates rolling integrated climb rate averages and thermal session climb statistics, providing pilots with dual-indicator vario instruments and dedicated thermal gain analysis.

## ADDED Requirements

### Requirement: Rolling Integrated Climb Rate Averaging
The telemetry pipeline SHALL maintain a continuous rolling sample window of barometric climb rates and compute the integrated average climb rate over a configurable time window (default 20 seconds, with options for 10, 15, 20, and 30 seconds).

#### Scenario: Real-time rolling averager calculation
- **WHEN** telemetry samples arrive at 1 Hz or higher
- **THEN** the rolling averager SHALL compute the arithmetic mean of valid climb rate samples within the configured time window.

#### Scenario: Stale or gap telemetry handling
- **WHEN** a gap between consecutive telemetry samples exceeds 5 seconds
- **THEN** the rolling climb sample buffer SHALL clear to prevent calculating inaccurate averages across interrupted flights.

### Requirement: Dual-Indicator Vario Bar Presentation
The vario lift/sink bar widget SHALL display both the instantaneous climb rate and the rolling integrated climb averager simultaneously across supported visual styles.

#### Scenario: Integrated averager needle on vertical edge bar
- **WHEN** `VarioLiftSinkBar` renders in vertical edge bar style
- **THEN** it SHALL display a primary bar representing instantaneous climb rate and a secondary distinct needle marker representing the rolling integrated average climb rate.

#### Scenario: Dual digital readout in regular tier
- **WHEN** `VarioLiftSinkBar` renders in regular content tier
- **THEN** it SHALL display both the instantaneous climb value (e.g., `+3.2`) and the integrated average value (e.g., `ø +1.8`).

#### Scenario: Audio threshold and sink alarm reference notches
- **WHEN** the vertical edge bar is rendered
- **THEN** it SHALL render subtle visual reference notches at the acoustic lift detection threshold (+0.2 m/s) and strong sink warning threshold (-2.0 m/s).

### Requirement: Thermal Session Statistics Tracking
The application SHALL track performance statistics for each circling session, capturing session start altitude, net altitude gain ($\Delta h$), average climb rate across the session, elapsed circling time, turn count, and peak climb rate.

#### Scenario: Automatic session activation on circling entry
- **WHEN** the flight mode transitions from gliding to circling
- **THEN** the thermal session tracker SHALL initialize a new session recording the entry altitude and timestamp.

#### Scenario: Live thermal statistics updates while circling
- **WHEN** the flight mode remains circling
- **THEN** the tracker SHALL continuously update net altitude gain, average climb rate, elapsed duration, turn count, and peak instantaneous climb rate.

#### Scenario: Session completion and retention on glide transition
- **WHEN** the flight mode transitions from circling to gliding
- **THEN** the thermal session tracker SHALL freeze the completed thermal statistics and retain them for display with a `LAST THERMAL` status until a new circling session begins.

### Requirement: Dedicated Thermal Stats Widget
The application SHALL provide a dedicated `thermalStats` instrument widget displaying thermal session altitude gain, average climb rate, elapsed time, and turn metrics.

#### Scenario: Live mode presentation
- **WHEN** the pilot is actively circling in a thermal
- **THEN** the `thermalStats` widget SHALL render live net altitude gain, thermal climb average, circling duration, and turn count.

#### Scenario: Retained last thermal view during glide
- **WHEN** the pilot exits a thermal into straight glide
- **THEN** the `thermalStats` widget SHALL display the frozen metrics from the last thermal tagged with a `LAST THERMAL` indicator badge.

#### Scenario: Size tier scaling
- **WHEN** the `thermalStats` widget is rendered in compact or tiny tier
- **THEN** it SHALL prioritize net altitude gain and average climb rate over secondary duration and turn count details.
