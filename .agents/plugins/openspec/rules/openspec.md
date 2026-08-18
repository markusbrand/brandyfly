---
name: openspec-workflow
description: Always follow OpenSpec change management guidelines when working on spec-driven changes.
---

# OpenSpec Integration Guidelines

When working with OpenSpec in this repository, follow these guidelines and CLI conventions:

Before using the `openspec` CLI, run `openspec --version` (or `npx @fission-ai/openspec --version`). If it is unavailable, suggest installing it with `npm install -g @fission-ai/openspec`.

## What is OpenSpec?

OpenSpec is a structured change management system for codebases. It organizes work into **changes** with planning artifacts (proposals, specs, designs, tasks) that guide implementation.

## Key CLI Commands

### Agent-Compatible CLI Commands (prefer `--json` for structured output)

| Command | Purpose |
|---------|---------|
| `openspec list [--json]` | List all changes and specs |
| `openspec show <item> [--json]` | View a specific change or spec |
| `openspec validate [--all] [--json]` | Validate changes and specs for issues |
| `openspec status [--change <name>] [--json]` | Show artifact progress for a change |
| `openspec instructions [artifact] [--change <name>] [--json]` | Get next-step instructions for a change |
| `openspec templates [--json]` | List available templates |
| `openspec schemas [--json]` | List available workflow schemas |
| `openspec archive <change> --json [--yes]` | Archive a completed change |

## Core Workflow

1. **Find the change**: Run `openspec list --json` to see active changes.
2. **Check progress**: Run `openspec status --change <name> --json` for the selected change.
3. **Follow instructions**: Run `openspec instructions [artifact] --change <name> --json` for the next artifact.
4. **Validate before completing**: Run `openspec validate <name> --json` or `openspec validate --all --strict`.

## Key Directories

- `openspec/` — Root OpenSpec directory
- `openspec/changes/` — Active changes with their planning artifacts
- `openspec/config.yaml` — Project configuration and rules

## Best Practices

- Always use the `--json` flag when programmatically parsing OpenSpec CLI output.
- Never edit or create changes manually by creating folders directly without scaffolding via `openspec new change <name>`.
- Run `openspec validate` after creating or modifying OpenSpec artifacts.
