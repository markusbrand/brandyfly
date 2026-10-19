## MODIFIED Requirements

### Requirement: Region-scoped prefetch coverage
For each downloaded map region, the application SHALL prefetch KK7 thermal tiles covering the region's bounding box for zoom levels 0 through 12, for the four time-of-day variants `all`, `morning`, `midday` and `evening` of the current season bin. The region bounding box SHALL be resolved from region catalog metadata when available, falling back to regional `meta.json` or local map archive headers.

#### Scenario: Coverage for a downloaded region
- **WHEN** prefetch completes for a downloaded region in July
- **THEN** every tile from zoom 0 to 12 intersecting the region's bounding box is stored for `thermals_jul_all`, `thermals_jul_04`, `thermals_jul_07` and `thermals_jul_10`

#### Scenario: Region without catalog metadata
- **WHEN** a region exists locally only as a map archive without catalog metadata
- **THEN** its bounding box is read from the archive header and prefetch proceeds

#### Scenario: Regional metadata bounds resolution
- **WHEN** a region contains a local `meta.json` with valid geographic bounds
- **THEN** the bounding box is successfully extracted and used for thermal prefetching

## ADDED Requirements

### Requirement: Runaway tile count protection
The prefetch service SHALL verify that the calculated tile count for a region does not exceed 25,000 tiles, and SHALL skip prefetch for regions exceeding this threshold to prevent resource exhaustion.

#### Scenario: Runaway tile count protection
- **WHEN** the calculated prefetch tile count for a region exceeds 25,000 tiles
- **THEN** the system logs a warning and skips prefetch for that region to protect disk and memory
