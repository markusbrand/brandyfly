## Purpose

Keeps KK7 thermal heatmap tiles available offline for every downloaded map region by prefetching the relevant season and time-of-day variants on the device, so the heatmap still works in flight without connectivity.

## ADDED Requirements

### Requirement: Region-scoped prefetch coverage
For each downloaded map region, the application SHALL prefetch KK7 thermal tiles covering the region's bounding box for zoom levels 0 through 12, for the four time-of-day variants `all`, `morning`, `midday` and `evening` of the current season bin. The region bounding box SHALL be taken from the region catalog metadata when available, otherwise from the region's local map archive header.

#### Scenario: Coverage for a downloaded region
- **WHEN** prefetch completes for a downloaded region in July
- **THEN** every tile from zoom 0 to 12 intersecting the region's bounding box is stored for `thermals_jul_all`, `thermals_jul_04`, `thermals_jul_07` and `thermals_jul_10`

#### Scenario: Region without catalog metadata
- **WHEN** a region exists locally only as a map archive without catalog metadata
- **THEN** its bounding box is read from the archive header and prefetch proceeds

### Requirement: Season transition lookahead
During the last calendar month of the current season bin (February, May, August, November), the application SHALL additionally prefetch the four time-of-day variants of the next season bin. Stored variants of season bins that are neither current nor next SHALL be deleted after the current season's variants are complete.

#### Scenario: Lookahead in late season
- **WHEN** prefetch runs for a region on 10 August
- **THEN** variants for both `jul` and `oct` are stored for that region

#### Scenario: Pruning outdated season
- **WHEN** prefetch for season `oct` completes for a region on 5 September
- **THEN** stored `jul` variants for that region are deleted

### Requirement: Automatic prefetch triggers
When prefetch is enabled, the application SHALL start prefetch automatically when a map region becomes available on the device, and when the required set of season variants for a region changes, the next time the device has network connectivity. Prefetch SHALL run in the background without blocking the UI, the map or flight instruments.

#### Scenario: New region downloaded
- **WHEN** a map region finishes downloading while the device is online
- **THEN** thermal prefetch for that region starts automatically

#### Scenario: Season window changes while offline
- **WHEN** the date enters a new season's lookahead window while the device is offline
- **THEN** prefetch for the newly required variants starts as soon as connectivity returns

#### Scenario: No impact on flight
- **WHEN** prefetch is running while flight instruments are displayed
- **THEN** instrument updates and map rendering continue without visible stutter

### Requirement: Manual refresh and progress
For each downloaded region the application SHALL show the thermal prefetch state (not prefetched, in progress with percentage, complete with storage size and season(s), failed or partial), and SHALL offer an action to start or retry prefetch for that region.

#### Scenario: Progress display
- **WHEN** prefetch for a region is 40% complete
- **THEN** the region shows thermal prefetch in progress at 40%

#### Scenario: Manual retry after failure
- **WHEN** a region's prefetch is shown as failed and the pilot triggers retry while online
- **THEN** prefetch resumes and fetches only the tiles that are still missing

### Requirement: Prefetch opt-out
The application SHALL provide a global setting to disable automatic thermal prefetch, enabled by default. When disabled, no automatic prefetch requests SHALL be issued. Manual per-region prefetch SHALL remain available.

#### Scenario: Opt-out on metered connection
- **WHEN** the pilot disables automatic thermal prefetch and then downloads a new region
- **THEN** no thermal tiles are prefetched for it until the pilot triggers prefetch manually

### Requirement: Polite and resumable fetching
Prefetch SHALL limit requests to thermal.kk7.ch to at most 4 per second and at most 2 concurrent requests, SHALL include the provider's `src` tracking parameter, SHALL skip tiles already stored, and SHALL resume after app restart or connectivity loss without re-downloading stored tiles. Requests SHALL NOT include pilot position, identity or device identifiers.

#### Scenario: Interrupted prefetch resumes
- **WHEN** connectivity is lost at 60% of a region's prefetch and later restored
- **THEN** prefetch continues from the stored tiles and the final tile count matches an uninterrupted run

#### Scenario: Rate limit respected
- **WHEN** a region prefetch runs on a fast connection
- **THEN** no more than 4 tile requests per second and no more than 2 concurrent requests are sent to thermal.kk7.ch

#### Scenario: Provider throttling or errors
- **WHEN** thermal.kk7.ch responds with HTTP 429 or 5xx errors
- **THEN** prefetch backs off exponentially, marks the region as partial if retries are exhausted, and keeps all tiles stored so far usable

### Requirement: Persistent region-bound storage
Prefetched thermal tiles SHALL be stored in persistent application storage that the operating system does not purge automatically, associated with their region, and SHALL be deleted when that region is deleted. Previously stored variants SHALL remain usable until newly required variants are completely stored.

#### Scenario: Survives OS cache cleanup
- **WHEN** the operating system clears the app's temporary cache directory
- **THEN** prefetched thermal tiles remain available offline

#### Scenario: Region deletion
- **WHEN** the pilot deletes a downloaded map region
- **THEN** the thermal tiles prefetched for that region are deleted and the reported storage usage decreases accordingly

#### Scenario: Stale data during refresh
- **WHEN** a season refresh is in progress or has failed for a region
- **THEN** the previously stored variants remain available for rendering
