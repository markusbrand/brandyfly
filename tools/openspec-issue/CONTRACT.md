# OpenSpec GitHub-issue change adapter contract

This boundary is the single, repository-owned integration surface that OpenSpec
workflows use to store change state in GitHub issues. Skills, prompts, and agent
guidance MUST call `openspec-issue.sh` rather than duplicating `gh` logic in
Markdown. There is **no local Markdown fallback**: when GitHub is unavailable or
access is insufficient the adapter fails explicitly and leaves remote state
unchanged.

## Why an adapter

GitHub issues are the authoritative store for every OpenSpec change (see
`openspec/specs/github-issue-change-management/spec.md`). Centralising the `gh`
calls here keeps the issue schema, marker handling, label lifecycle, validation,
and failure behaviour consistent across all workflows and testable with
fixtures.

## Issue schema (format version 1)

Each change is exactly one GitHub issue in the current repository. The issue
body is machine-updatable and human-readable:

1. A hidden metadata block (an HTML comment) carrying stable identity:

   ```
   <!-- openspec:metadata
   {
     "schemaVersion": 1,
     "changeName": "add-example-change",
     "specSchema": "spec-driven",
     "lifecycle": "implementing",
     "created": "2026-08-07",
     "archivedDate": null
   }
   openspec:metadata-end -->
   ```

   `changeName` (kebab-case) is the unique identifier — **not** the issue title.
   The issue number is the durable external reference.

2. Marker-delimited managed sections, each independently updatable:

   ```
   <!-- openspec:section:proposal:start -->
   ...content...
   <!-- openspec:section:proposal:end -->
   ```

   Managed section ids, in order: `proposal`, `requirements`, `design`,
   `tasks`, `verification`.

Any text outside the metadata block and the managed sections is user-authored
and is preserved verbatim on every update.

### Structural validation

`validate` and every mutating command enforce the full schema:

- exactly one metadata block (`^<!-- openspec:metadata$` … `^openspec:metadata-end -->$`),
  correctly ordered — duplicate or nested metadata blocks are rejected;
- metadata fields: `schemaVersion` exactly `1`; `changeName` nonempty kebab-case
  (`^[a-z0-9]+(-[a-z0-9]+)*$`); `specSchema` nonempty; `lifecycle` one of the
  valid lifecycles; `created` a valid `YYYY-MM-DD` calendar date; `archivedDate`
  present and either `null` or a valid `YYYY-MM-DD` date;
- the section markers appear exactly once each, in the fixed order, with no
  missing, duplicated, out-of-order, overlapping, or nested markers.

Malformed content is reported and never rewritten. Discovery (`list`, `find`,
and `create` duplicate detection) validates **every** `openspec`-labelled issue
and stops explicitly on the first malformed one, so a malformed issue cannot hide
a duplicate.

## Labels and lifecycle

Every issue carries the `openspec` discovery label plus exactly one lifecycle
label from:

| Lifecycle label       | Issue state | Meaning                                            |
| --------------------- | ----------- | -------------------------------------------------- |
| `openspec:proposed`   | open        | Proposal drafted, planning in progress             |
| `openspec:ready`      | open        | All planning artifacts complete, ready to apply    |
| `openspec:implementing` | open      | Apply in progress                                  |
| `openspec:completed`  | closed      | Verified and archived                              |

The sole lifecycle label MUST always equal the metadata `lifecycle` value;
`validate` enforces this exact label/metadata consistency.

Valid `set-lifecycle` transitions are enforced:

- `proposed -> ready`
- `ready -> proposed | implementing`
- `implementing -> proposed | ready | completed`
- `completed` is terminal (no outgoing transitions)

A transition to the current lifecycle is an idempotent no-op. Only `completed`
closes the issue. `create` (and migration) may seed an issue directly in any
valid initial lifecycle without going through transitions.

## Operations

`openspec-issue.sh <command> [args]`. Structured output is JSON on stdout;
diagnostics go to stderr. Non-zero exit means the operation did not succeed and
no partial success is claimed.

| Command | Purpose |
| ------- | ------- |
| `preflight [--write]` | Verify `gh`, authentication, repository resolution, and (with `--write`) issue write permission. |
| `ensure-labels` | Create the `openspec` and `openspec:*` labels if missing (idempotent), through classified failure handling, and verify all labels exist afterward. |
| `find <change-name>` | Print the issue number for a stable change name, or exit 3 if none. Exit 4 on duplicate. |
| `list [--state open|closed|all]` | List OpenSpec issues with number, change name, lifecycle, state, and task progress. |
| `create --name <n> --title <t> [--schema <s>] [--lifecycle <l>] [--created <date>] --body-file <f>` | Create one issue from a full managed body. Refuses duplicates. Any supplied `--schema`/`--lifecycle`/`--created` must exactly match the body metadata, the metadata `lifecycle` must be valid, and the created labels always derive from the body metadata. |
| `read <issue>` | Print the latest issue body. |
| `get-section <issue> <section>` | Print one managed section's inner content. |
| `set-section <issue> <section> --body-file <f>` | Replace one managed section from the latest body, preserving everything else. Post-write validated with rollback on failure. |
| `set-metadata <issue> --key <k> --value <v>` | Update one metadata field, preserving the rest. Post-write validated with rollback on failure. |
| `set-lifecycle <issue> <lifecycle>` | Enforce the documented transition, then atomically update label, state, and metadata; on any failure (label, close/reopen, body/metadata, or post-validation) it restores the prior body, labels, and state and reports failure with no success output. |
| `validate <issue>` | Post-write validation of the full schema above plus: exactly one lifecycle label equal to metadata `lifecycle`, and issue state consistent with lifecycle (`completed` ⇔ closed). |
| `scan-content --body-file <f>` | Reject secrets / private flight data before publishing. |

Discovery (`list`, `find`, and `create`'s duplicate check) retrieves **all**
matching issues via REST pagination (`OPENSPEC_ISSUE_PER_PAGE`, default 100), so
there is no fixed 200-item blind spot; every page is covered.

Creating a `completed` change is done safely: the issue is created in a valid
open `implementing` state, then completed through the atomic
`implementing -> completed` transition. If completion fails, the issue is left in
a valid, recoverable `implementing`/open state and creation reports failure (it
never claims success on partial failure and never leaves an invalid issue that
blocks retry).

## Error handling

The adapter distinguishes and reports (without echoing secret values):

- **connectivity** — GitHub unreachable; no success claim, no local artifact.
- **auth** — invalid/missing authentication.
- **permission** — read succeeds but the required write is not permitted; existing
  issue content is left unchanged.
- **duplicate** — a change name resolves to more than one issue.
- **malformed** — an `openspec`-labelled issue lacks valid metadata or well-ordered
  section markers; the adapter stops without rewriting it. Discovery halts on any
  malformed labelled issue.
- **sensitive** — content matches a credential / private-flight-data pattern.
- **body-size** — rendered body exceeds the GitHub issue body limit
  (`OPENSPEC_ISSUE_BODY_LIMIT`, default 65536); the write is refused so the last
  valid source state is preserved.

Every mutating command re-reads the latest issue immediately before writing and
runs `validate` after writing. `set-section` and `set-metadata` roll the body
back to the last valid state if post-write validation fails; `set-lifecycle`
additionally rolls back labels and open/closed state. Interrupted or partial
writes are detected and reported rather than reported as success.

## Configuration

- `OPENSPEC_ISSUE_REPO` — target `owner/repo` (defaults to the resolved repo).
- `OPENSPEC_ISSUE_GH` — `gh` binary to use (tests point this at a mock).
- `OPENSPEC_ISSUE_BODY_LIMIT` — max rendered body size in bytes.
- `OPENSPEC_ISSUE_PER_PAGE` — REST page size for discovery pagination (default 100).

## Testing

`tools/openspec-issue/test/run.sh` runs fixture-backed checks with a mock `gh`
(no network, no permanent issues): issue round trips, unmanaged-text
preservation, duplicate/malformed detection, interrupted updates, sensitive
content refusal, body-size limits, explicit GitHub failure behaviour,
metadata/label consistency, full metadata + section-marker-order validation,
malformed-issue discovery halting, pagination beyond 200 items,
lifecycle-transition enforcement, `create` flag validation, `ensure-labels`
verification (including permission/connectivity failures), atomic `set-lifecycle`
rollback at the label/body/close/post-validation stages (via mock failure
injection), completed-create staged recovery, and post-write rollback. It then
runs `tools/openspec-issue/test/run-migration.sh`, which exercises the migration
tool against a fixture change tree (created-date preservation, idempotent reuse,
conflict detection, and nonzero exit on per-item failure), and the guard
self-test. It also runs `check-local-change-storage.sh`, the repository
validation that fails when a workflow reintroduces per-change Markdown storage
assumptions (with `--self-test` proving positive wording is flagged while
prohibition/migration-history wording passes).
