## Purpose

Lets pilots place map zoom-in, zoom-out, zoom-rocker and recenter controls anywhere on a flight screen at any permitted size, driving a chosen map widget's camera with glove-friendly touch targets.

## ADDED Requirements

### Requirement: Placeable Map Control Widgets
The widget picker SHALL offer Map Zoom In, Map Zoom Out, Map Zoom Rocker (combined zoom in and out) and Map Recenter widgets. Each SHALL be placeable, movable, resizable and restacked like any other widget, and SHALL be added to the foreground of the stack.

#### Scenario: Adding a map control widget
- **WHEN** the pilot adds Map Recenter from the widget picker on a screen containing a map
- **THEN** a recenter control SHALL appear at its catalog default size in the foreground layer and be persisted.

#### Scenario: Rocker orientation follows shape
- **WHEN** a Map Zoom Rocker is sized taller than wide
- **THEN** zoom-in SHALL be on top and zoom-out on the bottom
- **AND** when sized wider than tall, zoom-out SHALL be on the left and zoom-in on the right.

### Requirement: Map Control Targeting
Each map control widget SHALL target either a specific map widget on the same screen variant or "Auto", which resolves to the bottom-most map widget in the stack of that variant. Targeting SHALL be configurable in the widget configuration sheet.

#### Scenario: Auto target with one map
- **WHEN** a map control is set to Auto and the screen variant contains exactly one map widget
- **THEN** the control SHALL drive that map.

#### Scenario: Explicit target among several maps
- **WHEN** a screen variant contains two map widgets and a zoom-in control targets the second
- **THEN** pressing zoom-in SHALL change only the second map's zoom.

#### Scenario: Target missing
- **WHEN** a map control's target map is removed, or Auto finds no map on the screen variant
- **THEN** the control SHALL render in a dimmed "no map" state, ignore presses, and not throw
- **AND** an explicit target that no longer exists SHALL be shown as "Missing map" in the configuration sheet with an option to switch to Auto.

### Requirement: Map Control Behavior Parity
Map control widgets SHALL produce the same camera behavior as the map widget's built-in controls: zoom steps of 0.5 levels clamped to the map's zoom range, zooming around the glider anchor while center-locked, and recentering that cancels the inactivity timer and restores center-lock.

#### Scenario: External zoom in while centered
- **WHEN** the target map is center-locked and the pilot presses an external zoom-in control
- **THEN** the map zoom SHALL increase by 0.5 and the glider SHALL remain at its orientation anchor point.

#### Scenario: External recenter during manual pan
- **WHEN** the pilot has panned the target map and presses an external recenter control before the 6-second inactivity timer expires
- **THEN** the timer SHALL be cancelled and the map SHALL return to center-locked tracking.

#### Scenario: Zoom changes are not persisted as configured zoom
- **WHEN** zoom is changed through a control widget in flight
- **THEN** the map's configured initial zoom level SHALL remain unchanged in storage.

### Requirement: Map Control State Feedback
Map control widgets SHALL reflect the current state of their target map within one frame of a change: the recenter control SHALL show an active (lit) state while the map is center-locked, and zoom controls SHALL appear disabled and ignore presses at the zoom range limits. The rocker SHALL display the current zoom level when its tier is regular.

#### Scenario: Recenter indicator after manual pan
- **WHEN** the pilot pans the target map
- **THEN** the recenter control SHALL switch from active to inactive
- **AND** return to active when center-lock is restored automatically or manually.

#### Scenario: Zoom limit reached
- **WHEN** the target map is at its maximum zoom
- **THEN** the zoom-in control (or rocker half) SHALL appear disabled and pressing it SHALL not change the camera.

### Requirement: Built-in Map Controls Visibility
Each map widget SHALL have a built-in controls setting with values Auto, Always and Never. Auto SHALL hide the map's built-in zoom and recenter buttons whenever at least one map control widget on the same screen variant resolves to that map, and show them otherwise.

#### Scenario: Auto hides built-ins when external controls exist
- **WHEN** a map's built-in controls setting is Auto and a recenter control targets it
- **THEN** the built-in zoom and recenter buttons of that map SHALL NOT be rendered.

#### Scenario: Auto restores built-ins when last control is removed
- **WHEN** the last map control targeting a map with setting Auto is removed
- **THEN** the map's built-in buttons SHALL reappear.

#### Scenario: Always and Never override
- **WHEN** the setting is Always or Never
- **THEN** the built-in buttons SHALL be shown or hidden respectively, regardless of external controls.

### Requirement: Map Control Operation Offline and During Replay
Map control widgets SHALL work identically online, offline, in simulation and during flight replay, and SHALL NOT depend on network access.

#### Scenario: Controls during replay
- **WHEN** a flight replay is running and the pilot presses an external zoom-out control
- **THEN** the target map SHALL zoom out and the replay telemetry stream SHALL be unaffected.
