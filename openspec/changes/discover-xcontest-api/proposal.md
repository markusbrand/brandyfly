## Why

Flight upload and access to other pilots' XContest flights are important later
features, but no documented API agreement is currently available. BrandyFly
must establish an authorised, stable integration path before credentials,
scheduled imports, or user-facing promises are implemented.

## What Changes

- Contact or otherwise use official XContest channels to establish supported
  upload and flight-catalog interfaces.
- Record authentication, credential storage, consent, rate limits, data fields,
  pagination, error semantics, retention, attribution, and redistribution terms.
- Validate a minimal direct-client upload flow only when test credentials and
  permission are provided.
- Determine whether the planned daily 08:00 `Europe/Vienna` catalogue update is
  permitted and technically sustainable.
- Produce an approve, blocked, or rejected decision for upload and catalogue
  capabilities independently.

Non-goals:

- Scrape private or undocumented endpoints.
- Store XContest credentials on the BrandyFly backend.
- Ship flight upload, catalogue synchronisation, or route planning.
- Promise access to data that XContest has not authorised for redistribution.

## Capabilities

### New Capabilities

- `xcontest-integration-readiness`: Defines the authorisation and technical
  evidence required before XContest upload or catalogue features are built.

### Modified Capabilities

None.

## Impact

The change affects integration documentation, optional isolated test tooling,
and the roadmap gates for upload, catalogue synchronisation, and route planning.
Credentials remain in platform secure storage during any authorised test and
must never enter fixtures, logs, CI, or the repository.
