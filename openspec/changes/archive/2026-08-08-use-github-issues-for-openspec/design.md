## Context

See `proposal.md` for motivation. Today the generated OpenSpec skills, prompts, and agent instructions assume that change state is discoverable from `openspec/changes/<name>/` and that artifact completion equals file existence. The replacement must work through the existing `gh` CLI, preserve durable capability specs in source control, migrate all current change history, and avoid split-brain behavior between files and issues.

The change-management path is developer tooling only. It does not run in BrandyFly's mobile, native, flight-core, map, or backend runtime, so it has no latency, battery, or platform-runtime impact.

## Goals / Non-Goals

**Goals:**

- Give each change a stable GitHub issue identity and make its latest issue body/state authoritative.
- Preserve the current proposal, delta-spec, design, task, verification, sync, and archive semantics.
- Make updates resumable and safe for human edits by changing only explicitly managed issue sections.
- Migrate active and archived changes with validation before deleting local artifacts.
- Keep failures explicit and recoverable.

**Non-Goals:**

- Forking or modifying the upstream OpenSpec CLI to add a GitHub storage backend.
- Moving durable capability specs or repository-wide OpenSpec configuration out of source control.
- Supporting non-GitHub forges or an offline writable change store.
- Adding change-management code to product runtime binaries.

## Decisions

### Use repository workflow instructions as the GitHub-backed adapter

The repository's OpenSpec skills, prompts, and agent guidance will implement issue-backed operations with `gh`, while durable specs and configuration remain compatible with the upstream CLI where useful.

This is preferred over forking the OpenSpec CLI because the repository already owns generated workflow instructions, and a fork would add a package distribution and maintenance burden. The trade-off is that CLI commands that inherently inspect `openspec/changes/` cannot be treated as authoritative after migration; workflow instructions must use issue-aware equivalents.

### Use one labeled issue with stable metadata and managed sections

Every issue will carry:

- an `openspec` label for discovery;
- one lifecycle label from a documented `openspec:*` set;
- a title suitable for humans;
- a hidden metadata block containing format version, stable change name, schema, and lifecycle data;
- marker-delimited sections for proposal, requirements, design, tasks, and verification.

Change names, not issue titles, are unique identifiers. The issue number is the durable external reference. Marker-delimited sections allow a workflow to fetch the latest body, replace one section, and preserve unrelated text.

Alternatives considered:

- A single unstructured issue body is easy to create but cannot be updated reliably.
- Separate issues per artifact fragment change context and violate the requested one-change/one-issue model.
- Issue comments as the primary event log preserve history but make current state expensive and ambiguous to reconstruct. Comments may supplement history, but the issue body remains current state.

### Treat GitHub state and labels as lifecycle data

Open issues represent active changes; closed issues represent completed/archived changes. Lifecycle labels expose finer progress such as proposed, ready, implementing, and completed. Workflows read the issue immediately before each mutation and update body plus labels together as closely as GitHub operations permit.

GitHub does not provide a transaction spanning body, labels, and state. Therefore operations validate the resulting issue after writes and report partial updates rather than claiming success. A retry starts from the latest remote state.

### Preserve main specs in the repository

Requirement deltas live in the issue while a change is active. Archive/sync workflows apply accepted deltas to `openspec/specs/`, which remain version-controlled behavioral contracts. This distinguishes durable product/framework specifications from transient per-change planning state.

Replacing main specs with issues was rejected because it would remove reviewable behavioral contracts from the code revision that implements them.

### Migrate before deleting

Migration processes each current change independently:

1. Read all local artifacts and metadata.
2. Create the corresponding open or closed issue.
3. Fetch and validate the issue's metadata, sections, task state, labels, and open/closed state.
4. Record the issue mapping.
5. Remove that local change directory only after validation.

Existing issue detection makes migration idempotent by stable change name. If an issue exists, migration validates and reuses it only when its content matches; conflicts stop that item. Repository file removals can be committed only after all intended migrations have passed, keeping rollback possible through Git history.

### Require explicit GitHub readiness

Every workflow that reads or writes changes first verifies repository resolution and required `gh` authentication/permissions. Read-only commands require issue read access; mutating commands require issue write access. There is no local artifact fallback because that would recreate two sources of truth.

Sensitive issue content is checked before publication. Errors identify the operation and remediation without printing credentials or private flight data.

## Risks / Trade-offs

- [GitHub outage blocks planning and updates] -> Report the outage and leave remote/local state unchanged; do not create fallback artifacts.
- [Concurrent human and agent edits can race] -> Fetch immediately before mutation, replace only one managed section, preserve unmanaged text, and validate after writing.
- [Body-size limits can affect large changes] -> Keep sections concise, detect the GitHub limit before destructive migration, and stop with local artifacts intact.
- [Label or marker drift can hide changes] -> Validate schema markers and labels on every operation and provide a repair path that requires explicit confirmation.
- [Migration can create issues before a later item fails] -> Make migration idempotent, validate each created issue, retain all unvalidated local directories, and report the exact completed mapping.
- [Public repositories expose planning details] -> Respect repository visibility, prohibit secrets/private flight data, and require explicit review of generated issue content.
- [Upstream OpenSpec updates may regenerate file-backed instructions] -> Keep the GitHub-backed conventions in repository-owned skills/instructions and add validation that detects reintroduced `openspec/changes/` assumptions.

## Migration Plan

1. Define and validate the issue schema, labels, lifecycle transitions, and managed-section update behavior.
2. Update all OpenSpec skills, prompts, and agent guidance to use the issue-backed adapter.
3. Create required labels and verify `gh` repository/authentication access.
4. Dry-run conversion of every active and archived change and inspect the generated issue payloads for sensitive content and size.
5. Create and validate open issues for active changes and closed issues for archived changes.
6. Remove migrated `openspec/changes/` directories, retaining only repository configuration and durable specs.
7. Verify list, create, continue, update, apply, sync, verify, archive, and interrupted-resume workflows against GitHub.

Rollback before file-removal commit is to delete or close newly created migration issues and retain local artifacts. After commit, Git history remains the recovery source; restoring local artifacts is an explicit rollback and must not run concurrently with issue-backed workflows.
