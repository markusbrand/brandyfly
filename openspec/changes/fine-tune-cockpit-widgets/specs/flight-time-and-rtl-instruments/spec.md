## MODIFIED Requirements

### Requirement: Flight Time Cockpit Instrument Widget
The application SHALL provide a placeable `flightTime` instrument widget displaying elapsed flight duration, current local clock time, takeoff timestamp, and offline-computed sunset countdown across responsive size tiers on the 16x32 virtual grid, supporting interactive tap-to-cycle and inspector configuration of the primary readout.

#### Scenario: Regular tier presentation
- **WHEN** `flightTime` is rendered in regular size tier
- **THEN** it SHALL display the active primary readout (**Flight Duration**, **Local Time of Day**, or **Sunset Countdown**) prominently with primary emphasis, alongside secondary readouts for the remaining time metrics and takeoff timestamp.

#### Scenario: Compact tier presentation
- **WHEN** `flightTime` is rendered in compact size tier
- **THEN** it SHALL display the active primary readout value alongside its mode label (`FLIGHT TIME`, `LOCAL TIME`, or `SUNSET IN`) and status or secondary clock.

#### Scenario: Tiny tier presentation
- **WHEN** `flightTime` is rendered in tiny size tier
- **THEN** it SHALL render the active primary readout digits scaled to fit the slot without labels or secondary clocks.

#### Scenario: Tapping widget cycles primary readout mode
- **WHEN** the pilot taps the `flightTime` widget during operative flight, simulation, or replay mode (outside layout Edit Mode)
- **THEN** the widget SHALL cycle its primary readout in order: `Flight Duration` -> `Local Time of Day` -> `Sunset Countdown` -> `Flight Duration`.

#### Scenario: Configuring default primary readout in inspector
- **WHEN** the pilot selects a primary readout mode (`Duration`, `Local Time`, or `Sunset`) in the `flightTime` widget configuration dialog
- **THEN** the selected mode SHALL be saved in `WidgetPlacementModel` and used as the widget's initial primary readout.

#### Scenario: Offline sunset countdown calculation
- **WHEN** `flightTime` displays the Sunset Countdown readout with valid GPS coordinates and date
- **THEN** it SHALL compute local civil sunset offline using the NOAA solar algorithm and display remaining time until sunset as `hh:mm` (or `PAST` when current time is after sunset, or `--:--` when coordinates are unavailable or in polar day/night).

#### Scenario: Pre-takeoff visual indication
- **WHEN** the aircraft is awaiting takeoff on the ground
- **THEN** the widget SHALL display `00:00` for flight duration with a subtle standby badge while showing the current local clock time and sunset countdown when selected.
