# OpenSpec Integration Guidelines

When working in this repository, always follow OpenSpec change management guidelines:

1. Use `openspec` / `npx openspec` CLI for managing changes and specifications.
2. For any feature or modification:
   - Create and validate planning artifacts (`proposal.md`, `specs/`, `design.md`, `tasks.md`) first.
   - Do not edit project code until planning is approved.
   - Apply tasks step-by-step and validate specs with `openspec validate --all --strict`.
3. Check status with `openspec status --change <name> --json`.
