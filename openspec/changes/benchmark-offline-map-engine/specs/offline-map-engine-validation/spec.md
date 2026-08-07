## Purpose

Defines repeatable offline functionality and mobile performance gates for
selecting the map engine used by BrandyFly during flight.

## ADDED Requirements

### Requirement: Benchmark data is representative and redistributable
The benchmark SHALL use a versioned Alpine-area PMTiles fixture containing
topographic base data, contours, hillshade, and representative dynamic overlay
geometries, with source, license, attribution, size, and checksum recorded.

#### Scenario: Benchmark fixture is prepared
- **WHEN** a benchmark run starts
- **THEN** the exact fixture version and checksum are included in its result

#### Scenario: Fixture rights are unclear
- **WHEN** redistribution or attribution requirements cannot be established
- **THEN** the fixture is not committed or used as release evidence

### Requirement: Core map workflows operate offline
Each candidate engine SHALL load the local map and execute pan, zoom, rotation,
track updates, airspace polygons, pilot markers, and thermal-style overlays with
all network access disabled.

#### Scenario: Offline benchmark
- **WHEN** the device has no network route and the valid fixture is installed
- **THEN** all benchmark workflows complete without an online tile request or blank base map

#### Scenario: Missing or corrupt fixture
- **WHEN** the local fixture is absent or fails checksum validation
- **THEN** the benchmark reports a data error and does not present partial content as a successful offline load

### Requirement: Mobile performance is measured reproducibly
The benchmark SHALL record cold-start-to-first-map latency, frame-time
distribution, frames over 16.7 ms, stalls over 100 ms, peak memory, and device
thermal state during a scripted workload of at least 10 minutes.

#### Scenario: Sixty-frame target is met
- **WHEN** a candidate runs the scripted workload on every designated Android and iOS reference device
- **THEN** at least 95 percent of measured frames complete within 16.7 ms and no sensor-pipeline stall is attributed to map work

#### Scenario: Device becomes thermally invalid
- **WHEN** a device begins the run outside the documented thermal state or throttles during setup
- **THEN** the run is excluded and repeated rather than reported as comparable evidence

### Requirement: Engine selection is evidence based
The decision record SHALL compare both candidates against identical fixtures and
workloads and select one candidate only when it passes offline and performance
gates on Android and iOS.

#### Scenario: One candidate passes
- **WHEN** exactly one candidate meets every mandatory gate
- **THEN** that candidate is selected and the rejected candidate's measured gaps are recorded

#### Scenario: No candidate passes
- **WHEN** neither candidate meets every mandatory gate
- **THEN** the map implementation remains blocked and the report identifies the next experiment instead of selecting the least failing option
