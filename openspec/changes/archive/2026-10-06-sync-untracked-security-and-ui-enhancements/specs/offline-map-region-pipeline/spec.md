## MODIFIED Requirements

### Requirement: Monthly automated execution
The pipeline SHALL run automatically on a monthly schedule via CI.

#### Scenario: Scheduled run
- **WHEN** the monthly CI schedule triggers
- **THEN** the pipeline downloads fresh OSM extracts from Geofabrik, regenerates all regions, and publishes updated files to CDN

#### Scenario: On-demand run
- **WHEN** a developer manually triggers the CI workflow
- **THEN** the pipeline runs identically to the scheduled execution

#### Scenario: External download source URL validation
- **WHEN** the pipeline download scripts fetch source datasets or PBF extracts
- **THEN** all download URLs SHALL be validated against trusted HTTPS scheme and domain prefixes (`https://download.geofabrik.de/`)
- **AND** any request to untrusted domains or insecure schemes SHALL be rejected with a security exception to mitigate Server-Side Request Forgery (SSRF)
