# XContest capability gates

## Upload gate

```yaml
capability: xcontest-direct-upload
decision:
  state: blocked
  evidence_date: 2026-08-07
  owner: Copilot
  revalidation_date: 2026-09-07
  unmet_conditions:
    - No published upload API or written XContest permission
    - No authorised test credentials
    - No documented success, duplicate, retry, or revocation semantics
scope: "Not for implementation until decision state is 'approved'"
```

Any implementation of direct flight upload to XContest SHALL NOT proceed until:
1. The decision state is explicitly `approved`
2. The revalidation date has not passed
3. A written contract covers the upload interface and all required fields

## Catalogue gate

```yaml
capability: xcontest-flight-catalogue
decision:
  state: blocked
  evidence_date: 2026-08-07
  owner: Copilot
  revalidation_date: 2026-09-07
  unmet_conditions:
    - No published catalogue API or written XContest permission
    - No documented pagination, rate-limit, or redistribution terms
    - 08:00 Europe/Vienna schedule is not confirmed as permitted
scope: "Not for implementation until decision state is 'approved'"
```

Any implementation of automated catalogue synchronisation or XContest-based route planning SHALL NOT proceed until:
1. The decision state is explicitly `approved`
2. The revalidation date has not passed
3. A written contract covers the catalogue interface, pagination, rates, and schedule

## Alternative schedule

If the default 08:00 `Europe/Vienna` daily schedule is not permitted, an alternative schedule
MAY be recorded in the catalogue gate and will remain blocked until the alternative is both
permitted and validated.

Current alternative: None recorded.

## Undocumented endpoint guard

No interface, endpoint, or field discovered through browser inspection, network observation,
or undocumented sources shall be promoted to `approved` status. The decision record must
remain `blocked` until official documentation or written permission covers the interface.
