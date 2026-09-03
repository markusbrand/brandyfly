## 1. Issue Schema & Metadata Token Support
- [ ] 1.1 Extend `validate_metadata_json` and `rewrite_metadata_field` in `tools/openspec-issue/openspec-issue.sh` to validate and manipulate optional `tokens` metadata.
- [ ] 1.2 Update `CONTRACT.md` with schema documentation for the `tokens` object and backward compatibility guarantees.

## 2. Adapter CLI Token Operations & Dynamic Labels
- [ ] 2.1 Implement token formatting helper (`format_token_badge`) and token label color mapping in `openspec-issue.sh`.
- [ ] 2.2 Implement `record-tokens` subcommand in `openspec-issue.sh` supporting incremental and replacement modes with atomic rollback.
- [ ] 2.3 Implement `get-tokens` subcommand in `openspec-issue.sh` to return JSON metrics for an issue.
- [ ] 2.4 Implement dynamic label synchronization logic to remove obsolete `tokens:*` labels and apply the current formatted badge label.

## 3. Central Token Ledger & Archival Integration
- [ ] 3.1 Implement `aggregate-tokens` subcommand in `openspec-issue.sh` to compile cumulative metrics into `openspec/token-usage.json` and `openspec/token-usage.md`.
- [ ] 3.2 Update `cmd_set_lifecycle` so transitioning an issue to `completed` triggers token aggregation and updates the central ledger files.
- [ ] 3.3 Create initial baseline `openspec/token-usage.json` and `openspec/token-usage.md`.

## 4. OpenSpec Skills & Workflow Guidance Integration
- [ ] 4.1 Update `.agents/plugins/openspec/skills/openspec-apply-change/SKILL.md` to instruct agents to record token usage upon task completion.
- [ ] 4.2 Update `.agents/plugins/openspec/skills/openspec-archive-change/SKILL.md` to document central ledger synchronization.
- [ ] 4.3 Update `openspec/specs/github-issue-change-management/spec.md` with the new token tracking requirements.

## 5. Automated Tests & Fixtures
- [ ] 5.1 Expand `tools/openspec-issue/test/run.sh` with fixture tests for `record-tokens`, dynamic label replacement, backward compatibility, and rollback on failure.
- [ ] 5.2 Add test cases for `aggregate-tokens` verifying `openspec/token-usage.json` and `openspec/token-usage.md` generation across multiple mock issues.
- [ ] 5.3 Run full adapter test suite and verify clean exit.
