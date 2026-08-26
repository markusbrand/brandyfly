---
name: openspec-archive-change
description: Finalize and complete an OpenSpec change tracked in a GitHub issue.
allowed-tools: Bash(openspec:*)
license: MIT
compatibility: Requires gh and openspec-issue adapter.
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.8.0"
---

Finalize and complete an OpenSpec change tracked in its authoritative GitHub issue.

**Input**: Change name or issue number.

**Steps**

1. **Select the Change**
   - Run `./tools/openspec-issue/openspec-issue.sh list` or `./tools/openspec-issue/openspec-issue.sh find "<name>"`.
   - Read the tasks and requirements from the issue.

2. **Verify Completion**
   - Confirm all tasks in the issue are marked `- [x]`.
   - Run test suite and static analysis (`flutter test`, `flutter analyze`).

3. **Sync Requirements into Durable Specs**
   - Extract delta specs from the issue's requirements section.
   - Synchronize accepted requirements into `openspec/specs/<capability-path>/spec.md`.

4. **Record Verification Evidence & Complete Issue**
   - Format verification evidence (test outputs, test counts, lint results).
   - Update verification section in the issue:
     ```bash
     ./tools/openspec-issue/openspec-issue.sh set-section <issue-number> verification --body-file <verification-file>
     ```
   - Complete and close the issue:
     ```bash
     ./tools/openspec-issue/openspec-issue.sh set-lifecycle <issue-number> completed
     ```

5. **Report Summary**
   - Display summary with issue number, synced specs, and completion status.
