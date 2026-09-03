## Why

AI-driven agentic development across OpenSpec change workflows (planning, task execution, testing, and verification) consumes significant quantities of LLM tokens. Currently, there is no standardized visibility into token consumption at the per-change level, nor is there a centralized ledger tracking aggregate token investment across the entire repository lifecycle. Paragliding pilots, developers, and maintainers need transparent token accounting, dynamic issue labels for at-a-glance token monitoring on GitHub issues, and a durable central ledger tracking project-wide token investments upon change archival.

## What Changes

- **Issue Metadata & Display**: Extend OpenSpec issue metadata schema to record structured token usage (`tokens: { input, output, cached, total, costUsd, lastUpdated }`) and display a human-readable Token Usage summary table/badge in the issue body.
- **Dynamic Token Labels**: Introduce dynamic GitHub issue labels formatted as `tokens:<formatted_count>` (e.g., `tokens:25k`, `tokens:140k`, `tokens:1.2M`) that automatically refresh on each token update by clearing previous token labels and applying the updated label.
- **Adapter CLI Commands**: Add `record-tokens`, `get-tokens`, and `aggregate-tokens` subcommands to `./tools/openspec-issue/openspec-issue.sh` with robust parameter validation, rollback on error, and label synchronization.
- **Central Project Ledger on Archival**: Update the change completion/archival workflow (`set-lifecycle <issue> completed` and `openspec-archive-change`) to automatically synchronize and compile all change token totals into a central repository ledger at `openspec/token-usage.json` and a markdown summary at `openspec/token-usage.md`.
- **Workflow & Skill Integration**: Update OpenSpec skills (`openspec-propose`, `openspec-apply-change`, `openspec-archive-change`) to record session token usage at the conclusion of workflow steps.
- **Automated Validation**: Expand `tools/openspec-issue/test/run.sh` to thoroughly test token metadata persistence, dynamic label refreshing, backward compatibility with unmetered issues, and central ledger aggregation.

## Capabilities

### Modified Capabilities
- `github-issue-change-management`: Extend the issue schema, adapter CLI, label lifecycle, and completion workflow to support issue-level token accounting, dynamic issue labels, and central project ledger updates upon archival.

## Non-Goals
- Real-time token streaming mid-prompt generation (token metrics are committed atomically per command/turn or workflow step).
- Provider billing API credentials or hard-coded proprietary rate calculations (token accounting accepts raw token counts and standard optional cost metrics).
- Replacing GitHub issues or JSON/Markdown files with external databases or SaaS observability tools.

## Impact
- **Adapter & Contract**: `tools/openspec-issue/openspec-issue.sh`, `tools/openspec-issue/CONTRACT.md`
- **Durable Specification**: `openspec/specs/github-issue-change-management/spec.md`
- **Central Ledger**: `openspec/token-usage.json`, `openspec/token-usage.md`
- **OpenSpec Skills**: `.agents/plugins/openspec/skills/`
- **Test Suite**: `tools/openspec-issue/test/run.sh`
