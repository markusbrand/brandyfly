## ADDED Requirements

### Requirement: Trusted source domain validation
The map pipeline data extraction scripts SHALL strictly validate remote download URLs against trusted upstream domains (`https://download.geofabrik.de/`) to prevent Server-Side Request Forgery (SSRF) and untrusted data ingestion.

#### Scenario: Download from trusted Geofabrik endpoint
- **WHEN** the extract downloader receives a URL starting with `https://download.geofabrik.de/`
- **THEN** the pipeline allows the download and proceeds with checksum verification and processing

#### Scenario: Download from untrusted or non-whitelisted URL
- **WHEN** the extract downloader receives a URL with an untrusted host or unapproved protocol scheme
- **THEN** the script immediately rejects the download with a security error and terminates without executing network requests
