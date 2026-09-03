# XContest contract summary

Awaiting written permission and detailed contract documentation from XContest.

## Known facts from public materials

- **Upload:** XContest accepts flight uploads via the XCTrack Android app. No public
  direct-API documentation was found.
- **Catalogue:** XContest publishes a searchable flight catalogue and live-tracking
  feature on their website. No public API documentation was found for automated
  retrieval.
- **Credentials:** XContest uses username/password authentication for user accounts.
  The privacy policy describes session management and storage.
- **Data fields:** Uploaded flights include GPS tracklogs (IGC format), descriptions,
  and photos.
- **Retention:** Per the privacy policy, XContest keeps personal information for up
  to 90 days after account termination unless longer retention is legally required.
- **Attribution:** XContest displays pilot usernames, flight descriptions, and
  glider model information publicly.
- **Redistribution:** Not documented in public materials. Per privacy policy,
  XContest does not redistribute to third parties except where required by law.

## Pending details

Awaiting response to official request. Required for approval:

- **Upload:** Published API or written permission; authentication; request/response
  contract; success/duplicate/retry/revocation semantics; rate limits; credential
  lifecycle; redistribution terms.
- **Catalogue:** Published API or written permission; authentication; pagination;
  filtering; incremental sync semantics; rate limits; caching constraints;
  redistribution terms; 08:00 `Europe/Vienna` schedule approval.

## Implementation guard

Any interface or data must be backed by official documentation or written XContest
permission. Undocumented observed endpoints are not used.

Evidence date: 2026-08-07
