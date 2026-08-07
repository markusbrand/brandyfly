# xcontest-integration-readiness Specification

## Purpose
Defines the authorisation, contract, privacy, and operability evidence required
before BrandyFly implements XContest upload or flight-catalogue features.
## Requirements
### Requirement: Interfaces require authoritative permission
The discovery report SHALL identify an official documented interface or written
XContest permission for each proposed integration and record the evidence source
and verification date.

#### Scenario: Only an undocumented endpoint is observed
- **WHEN** no official documentation or written permission covers an endpoint
- **THEN** that endpoint is excluded from prototypes and the related capability remains blocked

### Requirement: Upload and catalogue gates are independent
The report SHALL classify direct flight upload and flight-catalogue access
independently as approved, rejected, or blocked, with unmet conditions listed.

#### Scenario: Upload is allowed but catalogue access is not
- **WHEN** authoritative evidence permits upload but not catalogue retrieval
- **THEN** upload can pass its gate while catalogue synchronisation and dependent route planning remain blocked

### Requirement: Approved contracts are complete
An approved interface SHALL document endpoint ownership, authentication,
credential lifecycle, consent, request and response fields, pagination, rate
limits, idempotency, error semantics, retry constraints, retention,
attribution, and redistribution rights as applicable.

#### Scenario: Required contract detail is missing
- **WHEN** implementation cannot distinguish success, retryable failure, permanent failure, or duplicate submission from authoritative information
- **THEN** the affected interface remains blocked

### Requirement: Credentials and private flights remain protected
Any authorised prototype SHALL use dedicated test credentials from platform
secure storage and SHALL exclude credentials, session material, private flight
contents, and precise private locations from source control, fixtures, CI, and
logs.

#### Scenario: Prototype logging is inspected
- **WHEN** a test request or response is recorded
- **THEN** authentication material and private flight fields are absent or irreversibly redacted

### Requirement: Scheduled catalogue use is operationally valid
Catalogue approval SHALL confirm that incremental retrieval at the configured
default time of 08:00 `Europe/Vienna`, including daylight-saving transitions,
fits the permitted rate, pagination, caching, and redistribution constraints.

#### Scenario: Daily schedule is not permitted
- **WHEN** the authorised interface cannot support the planned daily update within its terms or rate limits
- **THEN** the catalogue gate remains blocked or records an explicitly permitted alternative schedule

### Requirement: Discovery decisions are time bounded
Each decision SHALL record an owner and revalidation date so implementation does
not rely indefinitely on stale API or policy evidence.

#### Scenario: Evidence expires before implementation
- **WHEN** the revalidation date has passed
- **THEN** implementation remains blocked until the evidence is renewed

