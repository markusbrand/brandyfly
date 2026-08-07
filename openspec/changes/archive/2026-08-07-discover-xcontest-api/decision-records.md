# XContest decision records

## Decision record template

| field | value |
| --- | --- |
| capability | |
| state | approved / rejected / blocked |
| evidence date | |
| owner | |
| unmet conditions | |
| revalidation date | |
| evidence sources | |

## Upload decision

| field | value |
| --- | --- |
| capability | direct flight upload |
| state | blocked |
| evidence date | 2026-08-07 |
| owner | Copilot |
| unmet conditions | No published upload API or written upload permission; no authorised test credentials; no contract details for success, duplicate, retry, or revocation handling. |
| revalidation date | 2026-09-07 |
| evidence sources | XContest FAQ, privacy policy, homepage |

## Catalogue decision

| field | value |
| --- | --- |
| capability | flight catalogue access |
| state | blocked |
| evidence date | 2026-08-07 |
| owner | Copilot |
| unmet conditions | No published catalogue API or written permission; no pagination, rate-limit, caching, or redistribution terms for automated retrieval; no confirmed 08:00 `Europe/Vienna` schedule approval. |
| revalidation date | 2026-09-07 |
| evidence sources | XContest FAQ, privacy policy, homepage |

## Rejected classification guard

Undocumented observed endpoints are never promoted to approved. If an endpoint is
seen only through browser or network observation and no official documentation or
written permission covers it, the decision remains blocked.
