# kk7-thermal-heatmap-layer Specification

## Purpose

Shows the thermal.kk7.ch statistical thermal probability heatmap on the flight map, filtered by season and time of day, so pilots can see where thermal uplift is likely, both online and offline.

## Requirements

### Requirement: Thermal heatmap toggle
The map widget SHALL render the KK7 thermal probability heatmap when the map widget's thermal setting ("Thermal Updraft Hotspots") is enabled, and SHALL NOT render it or request any thermal tiles when the setting is disabled. The setting SHALL default to enabled and SHALL persist per map widget.

#### Scenario: Pilot switches heatmap off
- **WHEN** the pilot disables "Thermal Updraft Hotspots" in the map widget configuration
- **THEN** the thermal heatmap disappears from that map widget within one second and no further thermal tile requests are issued for it

#### Scenario: Pilot switches heatmap on
- **WHEN** the pilot enables "Thermal Updraft Hotspots" in the map widget configuration
- **THEN** the thermal heatmap for the currently selected variant becomes visible on that map widget

#### Scenario: Setting survives restart
- **WHEN** the pilot disables the heatmap on a map widget and restarts the app
- **THEN** the heatmap remains disabled on that map widget

### Requirement: Season and time-of-day selection
Each map widget SHALL offer a thermal season setting with values `auto`, `all`, `jan` (December-February), `apr` (March-May), `jul` (June-August) and `oct` (September-November), and a time-of-day setting with values `auto`, `all`, `morning`, `midday` and `evening`. Both SHALL default to `auto`. A manually selected value SHALL be used unchanged regardless of date, time or position.

#### Scenario: Manual variant selection
- **WHEN** the pilot sets season to `jul` and time of day to `morning`
- **THEN** the map displays the KK7 `thermals_jul_04` variant at any date and time

#### Scenario: All-year all-day selection
- **WHEN** the pilot sets season to `all` and time of day to `all`
- **THEN** the map displays the KK7 `thermals_all_all` variant

### Requirement: Automatic season selection
When the season setting is `auto`, the application SHALL select the season bin from the current local calendar month: December, January and February map to `jan`; March, April and May to `apr`; June, July and August to `jul`; September, October and November to `oct`. The selection SHALL be computed on the device without network access.

#### Scenario: Season in mid-summer
- **WHEN** the season setting is `auto` and the current date is 15 July
- **THEN** the selected season bin is `jul`

#### Scenario: Season boundary
- **WHEN** the season setting is `auto` and the local date changes from 28 February to 1 March
- **THEN** the selected season bin changes from `jan` to `apr`

### Requirement: Automatic time-of-day selection
When time of day is `auto`, the application SHALL compute local sunrise on the device from the current date and pilot position. It SHALL select `morning` for 0 to <6 hours after sunrise, `midday` for 6 to <9 hours after sunrise, and `evening` for >=9 hours after sunrise. Before sunrise `morning` is selected; under polar day/night `all` is selected. Without GPS, the last known position or map center is used.

#### Scenario: Morning flight
- **WHEN** time of day is `auto`, sunrise at the pilot position was at 05:40 and the local time is 10:00
- **THEN** the selected time-of-day bin is `morning`

#### Scenario: Midday flight
- **WHEN** time of day is `auto`, sunrise at the pilot position was at 05:40 and the local time is 13:00
- **THEN** the selected time-of-day bin is `midday`

#### Scenario: Evening flight
- **WHEN** time of day is `auto`, sunrise at the pilot position was at 05:40 and the local time is 15:00
- **THEN** the selected time-of-day bin is `evening`

#### Scenario: No GPS fix
- **WHEN** time of day is `auto` and no GPS fix has been received yet
- **THEN** sunrise is computed from the last known position, or from the map view center if no position was ever known, and a variant is still displayed

#### Scenario: Offline computation
- **WHEN** the device has no network connectivity
- **THEN** automatic season and time-of-day selection still produces a variant

### Requirement: Variant switch during flight
When automatic selection produces a different variant while the map is displayed, the application SHALL switch the visible heatmap to the new variant within 60 seconds of the bin change, without interrupting map rendering, camera position, flight overlays or instrument updates.

#### Scenario: Morning to midday transition in flight
- **WHEN** the map is displayed in flight with time of day `auto` and 6 hours after sunrise elapse
- **THEN** the heatmap switches from the morning variant to the midday variant within 60 seconds while the pilot marker, track and instruments continue updating

### Requirement: Heatmap opacity
Each map widget SHALL offer a thermal heatmap opacity setting from 10% to 100% in steps of at most 10%, defaulting to 60%, applied to the heatmap layer only.

#### Scenario: Opacity adjustment
- **WHEN** the pilot sets the thermal opacity to 30%
- **THEN** the heatmap renders at 30% opacity while the base map and other overlays keep their opacity

### Requirement: Layer ordering
The thermal heatmap SHALL render above the base map and terrain relief and below airspace polygons, the flight track, the pilot marker and HUD controls.

#### Scenario: Airspace over heatmap
- **WHEN** the heatmap and airspace overlays are both visible in the same area
- **THEN** airspace polygons and the pilot marker are drawn on top of the heatmap

### Requirement: Thermal tile resolution order
The application SHALL resolve thermal tiles in priority order: region prefetch, persistent disk cache, then thermal.kk7.ch online. Online requests SHALL include the required `src` parameter and omit personal or device identifiers. Online tiles SHALL be cached locally. Unavailable tiles SHALL render transparently without error dialogs.

#### Scenario: Offline with prefetched region
- **WHEN** the device is offline and the map shows an area inside a region with prefetched tiles for the selected variant
- **THEN** the heatmap is rendered fully from local storage

#### Scenario: Offline without local tiles
- **WHEN** the device is offline and the map shows an area with no stored thermal tiles
- **THEN** that area shows no heatmap, the base map and flight overlays render normally, and no error dialog is shown

#### Scenario: Online browsing populates cache
- **WHEN** the pilot views an area online that is outside any downloaded region and later views it offline with the same variant
- **THEN** the previously viewed tiles are rendered from the persistent cache

#### Scenario: Provider unreachable
- **WHEN** thermal.kk7.ch does not respond within 5 seconds
- **THEN** the tile is rendered transparent and the map frame rate and flight instruments are unaffected

### Requirement: Thermal attribution
Whenever the thermal heatmap is visible, the map SHALL display or make accessible via the attribution control the text "Thermal map © thermal.kk7.ch, CC BY-NC-SA 4.0".

#### Scenario: Attribution while visible
- **WHEN** the thermal heatmap is enabled on a map widget
- **THEN** the KK7 attribution and license are visible or reachable from that map's attribution control

#### Scenario: No attribution when hidden
- **WHEN** the thermal heatmap is disabled
- **THEN** the KK7 attribution is not shown for that map widget
