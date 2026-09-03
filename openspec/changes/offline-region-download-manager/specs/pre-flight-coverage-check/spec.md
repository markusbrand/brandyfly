## ADDED Requirements

### Requirement: Pre-flight download prompt
The application SHALL detect when the pilot's GPS location is outside any downloaded region and show a dismissable prompt suggesting relevant region downloads.

#### Scenario: No coverage detected
- **WHEN** the pilot's GPS location is outside all downloaded regions and the app is in the foreground
- **THEN** a non-blocking prompt appears identifying the nearest/covering regions from the catalog and suggesting download, with estimated sizes

#### Scenario: Prompt dismissal
- **WHEN** the pilot dismisses the pre-flight download prompt
- **THEN** the prompt is dismissed and does not reappear for that session (or until the pilot moves to a different uncovered area)

#### Scenario: Pilot has coverage
- **WHEN** the pilot's GPS location is within a downloaded region
- **THEN** no download prompt is shown
