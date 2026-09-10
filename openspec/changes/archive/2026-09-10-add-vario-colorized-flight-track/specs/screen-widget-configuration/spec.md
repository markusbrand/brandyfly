## MODIFIED Requirements

### Requirement: Map track visualization settings
The UI configuration model and map settings interface SHALL allow pilots to configure the track history duration, older tail visibility, and vario color gradient thresholds.

#### Scenario: Configuring track history window
- **WHEN** the pilot accesses the Map Widget settings or UI settings panel
- **THEN** the system SHALL provide a history window selector offering options (e.g., 2, 5, 10, 15, 30 minutes, or Full Flight)
- **AND** updates to this setting SHALL immediately re-filter the rendered track polylines.

#### Scenario: Persisting map track preferences
- **WHEN** the user modifies map track history or threshold settings
- **THEN** the configuration SHALL be persisted in `UIConfig` and restored across application restarts.
