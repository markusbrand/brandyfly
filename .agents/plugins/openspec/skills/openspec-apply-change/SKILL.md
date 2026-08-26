---
name: openspec-apply-change
description: Implement tasks from an OpenSpec change tracked in a GitHub issue.
allowed-tools: Bash(openspec:*)
license: MIT
compatibility: Requires gh and openspec-issue adapter.
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.8.0"
---

Implement tasks from an OpenSpec change tracked in its authoritative GitHub issue.

**Input**: Change name or issue number. If omitted, infer from context or list active issues.

**Steps**

1. **Select & Fetch the Change Issue**
   - Run `./tools/openspec-issue/openspec-issue.sh list` to find active changes.
   - Read the issue content:
     ```bash
     ./tools/openspec-issue/openspec-issue.sh read <issue-number-or-name>
     ```
   - Transition lifecycle to `implementing` if currently `ready` or `proposed`:
     ```bash
     ./tools/openspec-issue/openspec-issue.sh set-lifecycle <issue-number> implementing
     ```

2. **Work Through Tasks**
   - Get the tasks list from the issue using:
     ```bash
     ./tools/openspec-issue/openspec-issue.sh get-section <issue-number> tasks
     ```
   - For each pending task (`- [ ]`):
     - Implement the code changes.
     - Validate via tests / analysis.
     - Mark task complete in local tasks file (`- [x]`).
     - Update the issue:
       ```bash
       ./tools/openspec-issue/openspec-issue.sh set-section <issue-number> tasks --body-file <updated-tasks-file>
       ```

3. **Wrap-up**
   - If all tasks are completed, notify the user that the change is ready to be archived with `/opsx-archive`.
