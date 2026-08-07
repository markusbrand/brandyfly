## 1. Evidence Framework

- [x] 1.1 Create separate upload and catalogue checklists for permission, authentication, contract, privacy, rate, caching, and redistribution evidence
- [x] 1.2 Define approve, rejected, and blocked decision records with evidence date, owner, unmet conditions, and revalidation date
- [x] 1.3 Review published XContest documentation and terms without probing undocumented private interfaces
- [x] 1.4 Send a focused official request for any missing upload and catalogue documentation or written permission

## 2. Authorised Contract Discovery

- [x] 2.1 Record the authorised upload contract, or mark upload blocked with the exact missing evidence
- [x] 2.2 Record the authorised catalogue contract, or mark catalogue access blocked with the exact missing evidence
- [x] 2.3 Document authentication lifecycle, consent, fields, pagination, rate limits, idempotency, errors, retries, retention, attribution, and rights where applicable
- [x] 2.4 Add checks that prevent an observed but undocumented endpoint from being classified as approved

## 3. Conditional Prototypes

- [ ] 3.1 If upload is authorised, build an isolated local prototype using dedicated secure test credentials and approved synthetic flight data
- [ ] 3.2 If upload is authorised, verify success, duplicate, retryable, permanent-failure, and credential-revocation outcomes without secret-bearing logs
- [ ] 3.3 If catalogue access is authorised, prototype incremental pagination with redacted or synthetic result fixtures
- [ ] 3.4 If catalogue access is authorised, test the 08:00 `Europe/Vienna` schedule across daylight-saving transitions against rate and caching constraints
- [x] 3.5 Verify repository history, fixtures, logs, and CI artifacts contain no credentials, sessions, or private flight locations

## 4. Gate Decisions

- [x] 4.1 Publish independent upload and catalogue decisions with permitted scope and expiry
- [x] 4.2 Gate direct-upload work on a current approved upload decision
- [x] 4.3 Gate catalogue synchronisation and XContest-based route planning on a current approved catalogue decision
- [x] 4.4 Record a permitted alternative schedule when the default daily schedule is not viable, or leave the catalogue gate blocked
- [x] 4.5 Run targeted decision-record tests and OpenSpec strict validation
