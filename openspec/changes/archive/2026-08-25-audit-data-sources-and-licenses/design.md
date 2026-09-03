## Context

See `proposal.md` for motivation. The MIT license covers BrandyFly source code,
not third-party data. Offline redistribution, derived tiles, live locations, and
long-lived caching can have different terms even when a provider offers public
web access. The audit must remain reviewable as terms change.

## Goals / Non-Goals

**Goals:**

- Make provider approval evidence consistent and time bounded.
- Prevent unapproved data from entering build and publication pipelines.
- Carry attribution and provenance into every distributable package.
- Define safe handling for stale, withdrawn, or privacy-sensitive sources.

**Non-Goals:**

- Replace professional legal review where terms remain ambiguous.
- Mirror production datasets during the audit.
- Assume public accessibility grants redistribution rights.

## Decisions

### Use one structured record per provider dataset

Each candidate receives a version-controlled record with fixed evidence fields,
decision state, reviewer, and revalidation date. Human-readable notes can link to
archived correspondence stored outside the repository when publication is not
permitted.

Alternative: one prose comparison document. Rejected because missing fields and
expired evidence are difficult to detect automatically.

### Require explicit approval at build time

Future data pipelines will resolve a provider record by stable dataset ID and
refuse publication unless its state is approved and review is current.

Alternative: allow blocked sources in development builds. Rejected because those
artifacts can be accidentally uploaded and contaminate derived outputs.

### Embed provenance in package manifests

Attribution and source metadata travel with each immutable package version,
rather than being reconstructed from the currently configured provider.

Alternative: keep attribution only in a global app acknowledgements page.
Rejected because offline packages can outlive providers and versions.

### Separate availability from installed-flight safety

Revocation blocks new builds and downloads immediately. Installed packages retain
their visible source date and attribution until a policy-specific removal path
is confirmed; the app does not delete the pilot's only map while in flight.

Alternative: remotely delete all affected data. Rejected because it can create
an immediate offline safety regression and may exceed contractual obligations.

## Risks / Trade-offs

- [Terms change without notice] -> Use review expiry, source monitoring, and
  package-version provenance.
- [An engineering interpretation is legally uncertain] -> Mark blocked and seek
  written permission or qualified review.
- [Machine-readable records oversimplify obligations] -> Keep evidence links and
  free-form conditions alongside mandatory fields.
- [Privacy duties vary by jurisdiction] -> Do not approve personal-data sources
  until consent, retention, deletion, and onward-sharing are explicit.

## Migration Plan

1. Define and validate the provider-record and package-provenance schemas.
2. Populate all required categories with approved, rejected, or blocked records.
3. Add a validation command that fails on missing, expired, or inconsistent
   approval metadata.
4. Make later package and provider changes depend on that validation.
5. If an approval is reversed, change its state, stop new publication, and
   follow the recorded incident response for existing versions.
