---
name: openspec-update-change
description: Update an OpenSpec change's planning sections in its GitHub issue.
allowed-tools: Bash(openspec:*)
license: MIT
compatibility: Requires gh and openspec-issue adapter.
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.8.0"
---

Update an OpenSpec change's planning sections in its authoritative GitHub issue.

**Steps**
1. Fetch latest section content using `./tools/openspec-issue/openspec-issue.sh get-section <issue> <section>`.
2. Revise content as requested.
3. Save updated section back to the issue:
   ```bash
   ./tools/openspec-issue/openspec-issue.sh set-section <issue> <section> --body-file <file>
   ```
