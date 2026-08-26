---
name: openspec-continue-change
description: Continue working on an OpenSpec change by creating or updating the next section in its GitHub issue.
allowed-tools: Bash(openspec:*)
license: MIT
compatibility: Requires gh and openspec-issue adapter.
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.8.0"
---

Continue an OpenSpec change by updating its sections in the authoritative GitHub issue.

**Steps**
1. Read the issue using `./tools/openspec-issue/openspec-issue.sh read <issue>`.
2. Identify missing or incomplete sections (`requirements`, `design`, `tasks`).
3. Draft the next section and update the issue:
   ```bash
   ./tools/openspec-issue/openspec-issue.sh set-section <issue> <section> --body-file <file>
   ```
4. Transition lifecycle if appropriate (`./tools/openspec-issue/openspec-issue.sh set-lifecycle <issue> <lifecycle>`).
