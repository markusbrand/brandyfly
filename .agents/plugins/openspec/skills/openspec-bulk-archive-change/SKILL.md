---
name: openspec-bulk-archive-change
description: Archive multiple completed OpenSpec change issues at once.
allowed-tools: Bash(openspec:*)
license: MIT
compatibility: Requires gh and openspec-issue adapter.
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.8.0"
---

Archive multiple completed OpenSpec changes tracked in GitHub issues.

**Steps**
1. For each completed change issue:
   - Sync requirement deltas to `openspec/specs/<capability>/spec.md`.
   - Complete issue:
     ```bash
     ./tools/openspec-issue/openspec-issue.sh set-lifecycle <issue> completed
     ```
