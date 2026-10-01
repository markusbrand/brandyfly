## ADDED Requirements

### Requirement: Recenter and Zoom from External Controls
The map SHALL accept zoom-in, zoom-out and recenter commands from map control widgets placed elsewhere on the screen, applying the same anchoring, center-lock and inactivity-timer rules as its built-in HUD buttons, and SHALL publish its center-lock state and zoom limits so external controls can reflect them.

#### Scenario: External recenter restores anchoring
- **WHEN** the map is in a temporary pan state and an external recenter command is received
- **THEN** the inactivity timer SHALL be cancelled, center-lock SHALL be restored, and the glider SHALL return to its orientation anchor (true center for North-Up, 50% width / 60% from top for Track-Up).

#### Scenario: External zoom during temporary pan
- **WHEN** the map is in a temporary pan state and an external zoom command is received
- **THEN** the map SHALL zoom around the current camera center and the 6-second inactivity timer SHALL be restarted.

#### Scenario: Center-lock state published
- **WHEN** center-lock changes due to a pan gesture, timer expiry, built-in button or external command
- **THEN** the new state SHALL be observable by external controls within one frame.

#### Scenario: Map disposed while controls exist
- **WHEN** the map widget is removed or the screen changes
- **THEN** pending commands from external controls SHALL be dropped without error and the inactivity timer SHALL be cancelled.
