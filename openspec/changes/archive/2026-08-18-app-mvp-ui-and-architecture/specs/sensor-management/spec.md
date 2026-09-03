## ADDED Requirements

### Requirement: [REQ-SENSOR-001] Sensor priority fallback
The application SHALL prioritize external Bluetooth variometers (e.g., SkyDrop) for telemetry data, and automatically fall back to internal device sensors if the external sensor is disconnected or unavailable.

#### Scenario: Bluetooth Sensor Disconnect
Given the application is receiving telemetry from a connected Bluetooth variometer
When the Bluetooth connection is lost
Then the application SHALL seamlessly transition to using internal device sensors for telemetry data
