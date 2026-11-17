# sensor-readiness-alert Specification

## Purpose

Continuously evaluates whether required live flight sensors (barometric/vario and GNSS/GPS) are available and producing valid readings, and displays a persistent top alert liner across the application until all required sensor values are present.

## ADDED Requirements

### Requirement: Required Flight Sensor Readiness Evaluation
The application SHALL continuously evaluate live sensor readiness across both the barometric/vario domain (onboard barometer or external vario) and the GNSS/GPS position domain. Readiness SHALL be satisfied only when both domains have active availability and valid, non-stale readings; idle placeholder values SHALL NOT satisfy readiness.

#### Scenario: Both barometer and GPS are missing at launch
- **WHEN** the application opens in live mode on a device with neither a working barometer nor a working GPS fix
- **THEN** sensor readiness is evaluated as insufficient
- **AND** both missing sensor domains (barometer and GPS) are identified in the readiness state.

#### Scenario: GPS is active while barometer is missing
- **WHEN** the application opens in live mode on a device with a valid GPS fix but no onboard barometer and no connected Bluetooth vario
- **THEN** sensor readiness is evaluated as insufficient
- **AND** the readiness state specifically identifies the missing barometer/vario source.

#### Scenario: Barometer is active while GPS is missing or denied
- **WHEN** the application opens in live mode with valid barometric readings, while GPS hardware is absent, location services are disabled, location permission is denied, or no valid fix has been acquired
- **THEN** sensor readiness is evaluated as insufficient
- **AND** the readiness state specifically identifies the missing GPS/location source.

#### Scenario: Readiness satisfied by combined onboard and Bluetooth vario sources
- **WHEN** a device lacks an onboard barometer but has a valid onboard GPS fix, and an external Bluetooth vario connects and delivers valid barometric/vario samples
- **THEN** both mandatory sensor domains are satisfied and sensor readiness transitions to ready.

#### Scenario: Readiness satisfied by external Bluetooth vario supplying all required domains
- **WHEN** an external Bluetooth vario connects and supplies valid barometric/vario and GNSS position readings
- **THEN** sensor readiness transitions to ready even if onboard device sensors are unavailable.

### Requirement: Persistent Top Alert Liner Presentation
Whenever the application is in live mode and sensor readiness is insufficient, the application SHALL render a high-contrast, compact warning alert liner anchored at the top of the application viewport within the system safe area. The alert liner SHALL remain continuously visible and SHALL NOT provide a permanent dismiss control while required sensor values remain missing or invalid.

#### Scenario: Alert liner displays immediately on startup with missing sensors
- **WHEN** the application opens in live mode without required sensor values
- **THEN** the alert liner appears at the top of the application stating which required sensors are unavailable (e.g., missing barometer, missing GPS) and indicating that connecting a Bluetooth vario or enabling device sensors is required.

#### Scenario: Alert liner persists across flight screens and orientations
- **WHEN** the pilot switches between customizable flight screens, toggles Edit Mode, or rotates between portrait and landscape across phone or tablet viewports while sensors remain insufficient
- **THEN** the top alert liner remains visible without layout overflow, text clipping, or obscuring system safe-area cutouts.

#### Scenario: Non-blocking interaction with navigation, settings, and offline logbook
- **WHEN** the top alert liner is visible
- **THEN** the pilot can still open the top navigation bar, navigate to Settings to pair/connect a Bluetooth vario or inspect permissions, and open the Flights logbook without obstruction.

#### Scenario: Coexistence with active airspace alert HUD
- **WHEN** both the insufficient-sensor alert liner and an airspace proximity warning banner are active simultaneously on a flight screen
- **THEN** both top banners stack cleanly without overlapping or hiding each other's primary warning text.

### Requirement: Automatic Clearing and Runtime Interruption Detection
The alert liner SHALL automatically clear as soon as valid readings are available for all required sensor domains, without requiring an application restart. If a required sensor stream subsequently disconnects, loses OS permission, or becomes stale during live operation, the alert liner SHALL automatically re-appear until valid readings resume.

#### Scenario: Alert liner clears automatically when Bluetooth vario connects
- **WHEN** the alert liner is visible due to a missing barometer and the pilot connects a Bluetooth vario that begins delivering valid barometric/vario samples alongside valid GPS coordinates
- **THEN** the alert liner automatically disappears within one telemetry update cycle without restarting the application.

#### Scenario: Alert liner clears automatically when late GPS fix arrives
- **WHEN** the alert liner is visible while waiting for an initial GPS fix alongside an active barometer and a valid GNSS fix subsequently arrives
- **THEN** the alert liner automatically clears once the valid fix is received.

#### Scenario: Alert liner re-appears on Bluetooth vario disconnection
- **WHEN** a device without an onboard barometer is flying/operating with a connected Bluetooth vario and the Bluetooth link disconnects
- **THEN** sensor readiness transitions back to insufficient
- **AND** the top alert liner re-appears identifying the lost barometric/vario source until the link reconnects and delivers valid samples.

#### Scenario: Alert liner re-appears on sensor staleness or stream timeout
- **WHEN** a required live sensor domain stops delivering valid samples for longer than the configured staleness threshold (default 5 seconds)
- **THEN** sensor readiness transitions to insufficient for the affected domain
- **AND** the top alert liner appears until fresh valid samples resume.

### Requirement: Suppression During Mock Flight and IGC Replay Modes
The live insufficient-sensor alert liner SHALL be suppressed while the application is intentionally operating in local mock/synthetic flight simulation mode or active IGC flight replay mode. Exiting replay mode back to live mode SHALL immediately re-evaluate live sensor readiness.

#### Scenario: Suppressed during local mock flight simulation
- **WHEN** the application runs in local mock/synthetic flight mode
- **THEN** the insufficient-sensor alert liner is not displayed even if physical device sensors are absent.

#### Scenario: Suppressed during IGC flight replay and restored on exit
- **WHEN** the pilot starts an IGC flight replay while live sensors are insufficient
- **THEN** the insufficient-sensor alert liner is hidden for the duration of the replay
- **AND WHEN** the pilot exits replay mode back to live mode while live sensors are still insufficient
- **THEN** the top alert liner immediately re-appears.

### Requirement: Offline Reliability and Honesty
Sensor readiness evaluation and top alert liner presentation SHALL function completely offline with zero network dependency and SHALL never fabricate synthetic readings to satisfy live sensor readiness.

#### Scenario: Offline launch on hardware lacking barometer
- **WHEN** the application opens without internet connectivity on a device lacking a barometer
- **THEN** the insufficient-sensor alert liner renders accurately using only local hardware, permission, and telemetry transport state.
