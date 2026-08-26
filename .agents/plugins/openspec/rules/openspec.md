---
name: openspec-workflow
description: Always follow OpenSpec change management guidelines when working on spec-driven changes.
---

# OpenSpec Integration Guidelines

In this repository, GitHub issues are the authoritative change store for all OpenSpec changes (see `openspec/specs/github-issue-change-management/spec.md` and `tools/openspec-issue/CONTRACT.md`).

All OpenSpec workflows MUST use the repository integration adapter `./tools/openspec-issue/openspec-issue.sh` to create, read, update, list, and complete changes. Never create or store per-change Markdown files under `openspec/changes/`.

## Key Adapter Commands (`./tools/openspec-issue/openspec-issue.sh`)

| Command | Purpose |
|---------|---------|
| `preflight [--write]` | Verify `gh` authentication and issue write permissions |
| `list [--state open\|closed\|all]` | List all OpenSpec issues with lifecycle, state, and task completion |
| `find <change-name>` | Find the issue number for a change name |
| `read <issue>` | Read the full issue body |
| `get-section <issue> <section>` | Read a managed section (`proposal`, `requirements`, `design`, `tasks`, `verification`) |
| `set-section <issue> <section> --body-file <f>` | Update a specific managed section in the issue |
| `set-lifecycle <issue> <lifecycle>` | Transition lifecycle (`proposed`, `ready`, `implementing`, `completed`) |
| `create --name <n> --title <t> --body-file <f>` | Create a new authoritative OpenSpec issue |
| `render-body --meta <f> ...` | Format an issue body with metadata and sections |
| `validate <issue>` | Validate an issue's schema, metadata, and sections |

## Core Workflow

1. **Discover & Select Change**: Run `./tools/openspec-issue/openspec-issue.sh list` or `./tools/openspec-issue/openspec-issue.sh find <change-name>`.
2. **Read Issue Content**: Read the authoritative proposal, requirements, design, and tasks from the issue using `./tools/openspec-issue/openspec-issue.sh get-section <issue> <section>`.
3. **Update Tasks During Implementation**: Update completed tasks (`- [x]`) in the issue using `./tools/openspec-issue/openspec-issue.sh set-section <issue> tasks --body-file <file>`.
4. **Complete & Archive**: Sync accepted requirement deltas to `openspec/specs/<capability>/spec.md`, record verification evidence, and complete the issue via `./tools/openspec-issue/openspec-issue.sh set-lifecycle <issue> completed`.

## Key Directories

- `openspec/` — Root directory
- `openspec/specs/` — Durable capability specifications (source controlled)
- `openspec/config.yaml` — Project configuration and rules
- `tools/openspec-issue/` — Authoritative GitHub issue change adapter and tools
