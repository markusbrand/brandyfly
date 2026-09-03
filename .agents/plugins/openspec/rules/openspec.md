---
name: openspec-workflow
description: Always follow OpenSpec change management guidelines when working on spec-driven changes.
---

# OpenSpec Integration Guidelines

When working in this repository, always follow OpenSpec specification-driven change management guidelines:

1. Use `openspec` / `npx openspec` CLI for managing changes and specifications under `openspec/changes/<change-name>/`.
2. For any feature, modification, or bug fix:
   - Create and validate planning artifacts (`proposal.md`, `specs/`, `design.md`, `tasks.md`) first.
   - Do not edit project code until planning is approved.
   - Apply tasks step-by-step and validate specs with `npx openspec validate --all --strict`.
3. Check status with `npx openspec status --change <name> --json`.
4. Archive completed changes with `npx openspec archive <change-name>`.

## Key Directories

- `openspec/` — Root OpenSpec directory
- `openspec/specs/` — Durable capability specifications (source controlled)
- `openspec/changes/` — Active changes and proposals
- `openspec/changes/archive/` — Completed and archived changes
- `openspec/config.yaml` — Project configuration and rules
