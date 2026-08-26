---
name: openspec-sync-specs
description: Sync delta specs from an issue to durable main specs in openspec/specs/.
allowed-tools: Bash(openspec:*)
license: MIT
compatibility: Requires gh and openspec-issue adapter.
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.8.0"
---

Sync delta specs from a GitHub issue's requirements section into durable capability specs under `openspec/specs/`.

**Steps**
1. Extract requirement deltas from the issue using `./tools/openspec-issue/openspec-issue.sh get-section <issue> requirements`.
2. For each capability, merge ADDED, MODIFIED, REMOVED requirements into `openspec/specs/<capability-path>/spec.md`.
3. Validate updated durable specs.
