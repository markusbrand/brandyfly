## Why

BrandyFly will redistribute or display map, elevation, airspace, live-pilot, and
thermal-derived data whose terms differ from the MIT source-code license.
Providers must be approved before implementation so offline packages and public
releases do not create licensing, privacy, or availability failures.

## What Changes

- Create a provider inventory for OSM extracts, elevation and hillshade,
  airspace, geocoding, live pilots, and related derived datasets.
- Record authoritative terms, attribution, redistribution, caching, retention,
  rate-limit, privacy, and update constraints for each candidate.
- Define an approve, reject, or blocked decision with evidence date and review
  owner.
- Define machine-readable attribution and provenance fields required in every
  generated data-package manifest.
- Document safe behaviour when a source is unavailable, stale, revoked, or no
  longer redistributable.

Non-goals:

- Download or publish production datasets.
- Treat this engineering audit as legal advice.
- Approve a source based on undocumented observed endpoints.
- Audit the XContest integration, which has its own discovery change.

## Capabilities

### New Capabilities

- `data-source-governance`: Defines the approval evidence, provenance,
  attribution, privacy, and lifecycle controls for third-party datasets.

### Modified Capabilities

None.

## Impact

The change primarily affects documentation, package-manifest contracts, and
future provider adapters. It gates map, airspace, geocoding, live-pilot, and
thermal work. No provider token, personal location, or non-redistributable data
is committed to the repository.
