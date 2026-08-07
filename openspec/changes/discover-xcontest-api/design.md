## Context

See `proposal.md` for motivation. BrandyFly has no XContest client, credentials,
or backend integration. Upload should eventually occur directly from the mobile
client, while catalogue metadata might use a scheduled backend job. Neither path
can proceed from undocumented observed endpoints.

## Goals / Non-Goals

**Goals:**

- Obtain independently reviewable authorisation and contracts for upload and
  catalogue access.
- Test only the minimum authorised behaviour needed to resolve uncertainty.
- Keep credentials and private flight data outside source control and CI.
- Produce explicit roadmap gates with expiry dates.

**Non-Goals:**

- Design the final synchronisation database or route-planning UI.
- Circumvent authentication, robots controls, or rate limits.
- Treat a successful browser request as integration permission.

## Decisions

### Start with official contact and published material

Discovery uses XContest documentation, terms, and direct written clarification.
The evidence record distinguishes public documentation from correspondence and
stores non-public material outside the repository while preserving a reviewable
reference.

Alternative: inspect the website or mobile traffic first. Rejected because an
observable private endpoint is not permission to automate or redistribute data.

### Gate upload and catalogue separately

Each capability has its own evidence checklist and approve, blocked, or rejected
decision. Route-planning work depends on catalogue approval, not merely upload
approval.

Alternative: a single XContest-compatible flag. Rejected because permissions,
authentication, rates, and data rights can differ substantially.

### Prototype with synthetic data and dedicated credentials

If authorised, an isolated local tool submits a synthetic or explicitly
designated test flight and records redacted protocol evidence. Secrets come from
platform secure storage or a local ignored secret, never command-line output,
fixtures, or CI.

Alternative: wire a prototype directly into the app. Rejected because incomplete
error and consent handling could leak credentials or create duplicate uploads.

### Model the Vienna schedule as a contract test

Catalogue feasibility includes rate-limit and pagination calculations plus
clock tests for 08:00 `Europe/Vienna` across daylight-saving transitions. The
schedule is accepted only if terms permit caching and downstream display.

Alternative: defer scheduling until backend implementation. Rejected because
the daily product promise can determine whether the interface is viable.

## Risks / Trade-offs

- [XContest does not respond or offer an API] -> Mark affected gates blocked and
  keep the features out of implementation scope.
- [Permission is informal or time limited] -> Record scope, owner, evidence date,
  and revalidation date; do not infer broader rights.
- [A test upload appears in public results] -> Use an explicitly approved test
  account and synthetic/non-private track agreed with XContest.
- [API terms change after implementation starts] -> Revalidate before the later
  implementation change and keep adapters isolated.

## Migration Plan

1. Create evidence checklists without adding runtime dependencies.
2. Seek official documentation or written clarification.
3. Run an isolated test only for explicitly authorised interfaces.
4. Publish redacted contract and decision records.
5. Later OpenSpec changes may proceed only for gates that are approved and
   current; blocked or rejected paths add no application or backend code.
