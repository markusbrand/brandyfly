## Verification evidence

### Adapter and automated checks
- `tools/openspec-issue/openspec-issue.sh` implements the GitHub-issue adapter (schema v1, hidden metadata, marker-delimited sections `proposal|requirements|design|tasks|verification`, `openspec` + `openspec:{proposed,ready,implementing,completed}` labels, section-preserving updates, post-write validation, and explicit connectivity/auth/permission/duplicate/malformed/sensitive/body-size handling with no local fallback). Contract: `tools/openspec-issue/CONTRACT.md`.
- Fixture-backed tests: `bash tools/openspec-issue/test/run.sh` → **22 passed, 0 failed** (round trips, unmanaged-text preservation, duplicate/malformed detection, interrupted/partial-write detection, sensitive-content refusal, body-size limit, and connectivity/auth/permission failure behavior — all with a mock `gh`, no network, no permanent issues).
- Repository guard: `tools/openspec-issue/check-local-change-storage.sh` fails if per-change Markdown storage is reintroduced. Both checks are wired into the CI `openspec` job.
- Durable-spec validation: `npx --yes @fission-ai/openspec@latest validate --all --strict` → all specs pass, including the synced `github-issue-change-management` durable spec under `openspec/specs/`.

### Migration mapping (change name → issue)
| Change | Issue | State | Lifecycle |
| --- | --- | --- | --- |
| add-local-mock-flight-mode | #15 | open | implementing |
| audit-data-sources-and-licenses | #16 | open | implementing |
| benchmark-offline-map-engine | #17 | open | proposed |
| use-github-issues-for-openspec | #18 | closed | completed |
| validate-native-flight-pipeline | #19 | open | proposed |
| validate-skydrop1-protocol | #20 | open | proposed |
| bootstrap-brandyfly-monorepo | #21 | closed | completed |
| discover-xcontest-api | #22 | closed | completed |

Migration is idempotent (re-running `migrate-local-changes.sh apply` reused all issues; exactly one issue per change name). Each issue was post-write validated. All migrated content was scanned for secrets and private flight data before publishing; only policy/requirement text mentioning secrets remains (no actual credentials or flight records).

### Cutover
- All per-change directories under `openspec/changes/` (active, archived, and this migration change) removed after their issues were created and validated.
- `openspec/config.yaml` and durable specs under `openspec/specs/` preserved.
- Repository-wide search found no remaining authoritative `openspec/changes/<name>` assumptions (only explicit prohibition/migration-history wording).
- Skills, prompts, agent guidance, README, CONTRIBUTING, and docs/development.md updated to treat GitHub issues as the authoritative change store.

### Unresolved limitations
- The upstream `openspec` CLI still inspects `openspec/changes/`; repository workflows use the issue-backed adapter instead and the CI guard detects any reintroduced local storage.
- GitHub does not provide a single transaction across body, labels, and state; the adapter re-reads before writes and validates after writes, reporting partial updates rather than claiming success.

### Post-review fixes (2026-08-08)
Addressed code-review findings on the adapter and migration tooling; all fixes
carry regression tests (`tools/openspec-issue/test/run.sh` → 40 adapter checks;
`tools/openspec-issue/test/run-migration.sh` → 8 migration checks; both wired
into the CI `openspec` job):

1. All 12 `.github/skills/openspec-*/SKILL.md` frontmatters now permit the adapter (`allowed-tools: Bash(tools/openspec-issue/openspec-issue.sh:*), Bash(gh:*), Bash(npx:*), Bash(openspec:*)`) and updated `compatibility`.
2. `validate` now enforces that the sole lifecycle label equals metadata `.lifecycle` (regression test added).
3. `set-metadata` now post-write validates and rolls back on failure; failures are never success-shaped.
4. `ensure-labels` routes through classified failure handling and verifies every label exists afterward (permission/connectivity regression tests added).
5. `set-lifecycle` enforces documented transitions (proposed→ready; ready→proposed|implementing; implementing→proposed|ready|completed; completed terminal); invalid transitions are refused (tests added).
6. `create` validates `--schema`/`--lifecycle`/`--created` (when supplied) and the metadata lifecycle against the body, deriving labels from metadata (tests added).
7. Migration preserves each source `.openspec.yaml` `created` date (archive prefix fallback); the real issues #15–#22 were repaired to `created=2026-08-07` and re-validated.
8. Migration now tracks per-item failures and exits nonzero, preserving per-item diagnostics.
9. Idempotent reuse now compares the generated payload's managed sections and key metadata against the existing issue and fails on conflict instead of silently reusing.
10. `set-section` and `set-metadata` roll back to the previous valid body if post-write validation fails.

Verified after fixes: adapter suite (40) + migration suite (8) pass, local-storage guard passes, `openspec validate --all --strict` passes, and issues #15–#22 validate with `created=2026-08-07` (archived #21/#22 retain `archivedDate=2026-08-07`).

### Second-review fixes (2026-08-08)
A further code review raised 9 findings; all are fixed with regression tests
(`tools/openspec-issue/test/run.sh` → **61 adapter checks**;
`tools/openspec-issue/test/run-migration.sh` → **8 migration checks**; both wired
into the CI `openspec` job):

1. **Archive prerequisites are hard-blocking.** `opsx-archive` (prompt + skill) and `opsx-bulk-archive` (prompt + skill) now require all tasks complete, successful verification evidence, and accepted deltas synced (or absent) before completing/closing — with no user override. Bulk archive classifies each change eligible/ineligible; confirmation only selects among eligible changes.
2. **Apply lifecycle honors the transition graph.** Apply skill/prompt no longer do `proposed -> implementing` (which the adapter forbids); they read the lifecycle and advance `proposed -> ready -> implementing` only when readiness criteria (all planning sections present and a non-empty tasks list) hold, else stop.
3. **Atomic `set-lifecycle` recovery.** The transition captures prior body, lifecycle labels, and open/closed state and restores all three on failure at any stage (label, body/metadata, close/reopen, post-validation), returning failure with no success output. Tested with mock failure injection at each stage.
4. **Completed-issue creation recovery.** Completed changes are created in a valid open `implementing` state then completed via the atomic transition; on completion failure the issue is left valid/recoverable and creation reports failure (never success-shaped, never an invalid issue that blocks retry). Failure-injection + retry tested.
5. **No 200-issue blind spot.** Discovery/find/duplicate/list retrieve every matching issue via REST pagination (`OPENSPEC_ISSUE_PER_PAGE`). A mock test proves find + duplicate detection at issue #201.
6. **Malformed labeled issues halt discovery.** `list`/`find`/`create` validate every `openspec`-labeled issue and stop explicitly on malformed metadata/markers; duplicate creation is blocked even when another labeled issue is malformed. Tested.
7. **Complete metadata/marker validation.** Enforces schemaVersion==1, kebab-case changeName, nonempty specSchema, valid lifecycle, valid YYYY-MM-DD created, archivedDate null-or-date, exact section-marker order/non-overlap, and rejects duplicate/nested/out-of-order markers. Comprehensive tests added.
8. **Stronger local-storage guard.** Matches exact `openspec/changes/` and child paths; the allow-list no longer exempts a positive instruction merely for mentioning "GitHub issue". A `--self-test` (wired into the suite) proves positive wording is flagged while prohibition/migration-history wording passes.
9. **Sync path consistency.** `opsx-sync` prompt no longer infers/guesses a missing `<capability-path>`; it requires an explicit path in the issue requirements or a user-confirmed concrete path, matching the skill.

Re-verified: adapter suite (61) + migration suite (8) pass; local-storage guard + self-test pass; `openspec validate --all --strict` passes (4 durable specs); issues #15–#22 validate under the stricter rules and contain no secrets/private flight data. This issue remains completed/closed with 25/25 tasks.
