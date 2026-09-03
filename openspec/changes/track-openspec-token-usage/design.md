## Context

The OpenSpec framework in BrandyFly utilizes GitHub issues as the single authoritative store for feature changes, specifications, and task tracking. Autonomous and pair-programming AI coding agents spend millions of tokens across the lifecycle of each change. However, there is currently no systematic mechanism to record per-issue token consumption, show at-a-glance token badges in GitHub issue lists and issue views, or calculate total project-wide token investment.

## Goals & Non-Goals

### Goals
- Store machine-readable token metrics (`input`, `output`, `cached`, `total`, `costUsd`, `updatedAt`) directly inside the issue metadata block.
- Provide a clean summary representation in the issue body.
- Automatically assign and refresh compact, color-coded `tokens:<formatted_count>` labels on GitHub issues.
- Aggregate all completed change tokens into durable central files (`openspec/token-usage.json` and `openspec/token-usage.md`) upon archival.
- Provide CLI subcommands in `tools/openspec-issue/openspec-issue.sh` to record, query, refresh, and aggregate tokens.

### Non-Goals
- Fine-grained per-turn streaming telemetries during LLM execution.
- Complex third-party observability SaaS vendor tie-ins.

## Technical Decisions

### 1. Metadata Schema Extension
The JSON block inside the issue metadata header is extended with an optional `tokens` object:
```json
{
  "schemaVersion": 1,
  "changeName": "track-openspec-token-usage",
  "specSchema": "spec-driven",
  "lifecycle": "implementing",
  "created": "2026-08-26",
  "archivedDate": null,
  "tokens": {
    "input": 124500,
    "output": 18200,
    "cached": 45000,
    "total": 142700,
    "costUsd": 0.32,
    "updatedAt": "2026-08-26T10:45:00Z"
  }
}
```
Validation rules:
- `tokens` is optional; if present, `input`, `output`, and `total` must be non-negative integers.
- Existing issues without `tokens` remain 100% compliant with Schema Version 1.

### 2. Label Naming & Formatting Scheme
Format: `tokens:<compact_number>`
- `< 1,000`: `tokens:<1k` (Color: `#cfd3d7` Light grey)
- `1,000 - 99,999`: `tokens:XXk` (e.g. `tokens:25k`, `tokens:84k`, Color: `#0e8a16` Green)
- `100,000 - 999,999`: `tokens:XXXk` (e.g. `tokens:120k`, `tokens:650k`, Color: `#fbca04` Yellow)
- `1,000,000+`: `tokens:X.XM` (e.g. `tokens:1.2M`, `tokens:3.5M`, Color: `#d93f0b` Orange / `#6f42c1` Purple)

When updating tokens, all existing labels matching `tokens:*` on the issue are removed before adding the new label.

### 3. Central Token Ledger Architecture
Upon change completion (`set-lifecycle <issue> completed`), or via `aggregate-tokens`:
- `openspec/token-usage.json`:
  ```json
  {
    "lastUpdated": "2026-08-26T12:00:00Z",
    "totals": {
      "inputTokens": 2450000,
      "outputTokens": 380000,
      "totalTokens": 2830000,
      "costUsd": 5.42,
      "archivedChangesCount": 18
    },
    "changes": [
      {
        "issueNumber": 61,
        "name": "flight-tracking-logbook-and-replay",
        "lifecycle": "completed",
        "inputTokens": 180000,
        "outputTokens": 25000,
        "totalTokens": 205000,
        "costUsd": 0.45
      }
    ]
  }
  ```
- `openspec/token-usage.md`: Auto-generated markdown table displaying cumulative totals and per-change breakdown.

### 4. Adapter CLI Subcommands
- `record-tokens <issue> --input <N> --output <M> [--cached <K>] [--cost <USD>] [--incremental|--replace]`
- `get-tokens <issue>` (returns structured JSON token counts)
- `refresh-token-label <issue>`
- `aggregate-tokens [--output-json <path>] [--output-md <path>]`

## Risks and Trade-offs

- **GitHub API Rate Limits / Latency**: Aggregating tokens across all issues uses the existing paginated issue cache (`load_openspec_issues`) to minimize API calls.
- **Concurrent Label Updates**: Rollback handlers guarantee that if label addition or removal fails, the previous valid state is restored without leaving corrupted labels.
