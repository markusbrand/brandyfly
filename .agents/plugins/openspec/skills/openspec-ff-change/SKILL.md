---
name: openspec-ff-change
description: Fast-forward through OpenSpec change creation, creating all sections in the GitHub issue at once.
allowed-tools: Bash(openspec:*)
license: MIT
compatibility: Requires gh and openspec-issue adapter.
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.8.0"
---

Fast-forward through OpenSpec change creation directly into an authoritative GitHub issue.

**Steps**
1. Draft `proposal`, `requirements`, `design`, and `tasks`.
2. Render body and scan content.
3. Create issue:
   ```bash
   ./tools/openspec-issue/openspec-issue.sh create --name "<name>" --title "OpenSpec: <name>" --schema spec-driven --lifecycle ready --body-file <file>
   ```
