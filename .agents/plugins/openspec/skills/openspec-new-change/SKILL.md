---
name: openspec-new-change
description: Start a new OpenSpec change. Use when the user wants to create a new feature, fix, or modification with a structured step-by-step approach backed by GitHub issues.
allowed-tools: Bash(openspec:*)
license: MIT
compatibility: Requires gh and openspec-issue adapter.
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.8.0"
---

Start a new change using GitHub issues as the authoritative change store.

**Input**: The user's request should include a change name (kebab-case) OR a description of what they want to build.

**Steps**

1. **Verify Preflight & Understand Request**
   - Run `./tools/openspec-issue/openspec-issue.sh preflight --write`
   - If no clear input is provided, ask what they want to build.
   - Derive a kebab-case name (e.g., `rework-screen-widget-settings`).

2. **Check for Duplicate Names**
   - Run `./tools/openspec-issue/openspec-issue.sh find "<name>"` to confirm the name is unique.

3. **Draft the Proposal Section**
   - Follow `openspec/config.yaml` guidelines (Why, What Changes, Capabilities, Non-Goals, Impact).

4. **Create the Authoritative Issue**
   - Render the initial issue body with metadata and proposal section.
   - Run `./tools/openspec-issue/openspec-issue.sh scan-content --body-file <file>`
   - Create the issue:
     ```bash
     ./tools/openspec-issue/openspec-issue.sh create --name "<name>" --title "OpenSpec: <name>" --schema spec-driven --lifecycle proposed --body-file <file>
     ```
   - Report the created issue number. Never create per-change storage under `openspec/changes/`.
