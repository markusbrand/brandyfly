---
name: openspec-verify-change
description: Verify implementation matches change artifacts in the GitHub issue.
allowed-tools: Bash(openspec:*)
license: MIT
compatibility: Requires gh and openspec-issue adapter.
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.8.0"
---

Verify implementation against the authoritative GitHub issue.

**Steps**
1. Fetch requirements and tasks from the issue:
   ```bash
   ./tools/openspec-issue/openspec-issue.sh get-section <issue> requirements
   ./tools/openspec-issue/openspec-issue.sh get-section <issue> tasks
   ```
2. Execute tests and validation suites (`flutter test`, `flutter analyze`).
3. Record evidence into the issue's verification section:
   ```bash
   ./tools/openspec-issue/openspec-issue.sh set-section <issue> verification --body-file <evidence-file>
   ```
