## ADDED Requirements

### Requirement: [REQ-WIDGET-001] Map background widget
The application SHALL provide a background map widget supporting multiple sources, initially focusing on OpenStreetMap.

#### Scenario: Displaying the Map
Given the user has added a Map widget to the current screen
When the screen is active
Then the Map widget SHALL render the selected map source at the configured bounds

### Requirement: [REQ-WIDGET-002] Essential flight widgets
The application SHALL provide widgets for groundspeed, altitude, wind direction, wind speed, height above ground, glide ratio, flight height line chart, and a visual lift/sink rate bar.

#### Scenario: Displaying Vario Bar
Given the user has added a visual lift/sink rate bar widget
When the flight core reports a lift rate of +2.0 m/s
Then the widget SHALL display a green bar extending above the center zero line
When the flight core reports a sink rate of -1.5 m/s
Then the widget SHALL display a red bar extending below the center zero line
