## MODIFIED Requirements

### Requirement: Issue token accounting metadata and representation
The OpenSpec GitHub issue schema SHALL support tracking token usage metrics within the machine-readable metadata block while maintaining backward compatibility with issues that do not contain token data.

#### Scenario: Record token consumption on an issue
- **WHEN** a workflow or developer invokes `openspec-issue.sh record-tokens <issue> --input <N> --output <M>`
- **THEN** the adapter SHALL update the issue metadata block with updated `input`, `output`, and computed `total` token counts and a timestamp
- **AND** preserve all other metadata fields, managed sections, and user-authored text.

#### Scenario: Validate issue without token metadata
- **WHEN** an issue contains schemaVersion 1 metadata without a `tokens` object
- **THEN** structural validation SHALL pass successfully
- **AND** token queries on the issue SHALL treat missing metrics as zero.

### Requirement: Dynamic token label synchronization
The adapter SHALL maintain an up-to-date token usage label on each OpenSpec GitHub issue, automatically replacing any preexisting token label whenever new token metrics are recorded or refreshed.

#### Scenario: Applying and refreshing token labels
- **WHEN** token counts are recorded or refreshed on an issue
- **THEN** the adapter SHALL format the total token count into a standard compact badge label (e.g. `tokens:<1k`, `tokens:25k`, `tokens:140k`, `tokens:1.2M`)
- **AND** remove any previously attached `tokens:*` label before attaching the new label.

#### Scenario: Refresh labels across all open issues
- **WHEN** `openspec-issue.sh refresh-token-labels` is invoked
- **THEN** the adapter SHALL inspect all OpenSpec issues and synchronize each issue's token label to its metadata token count.

### Requirement: Central project token aggregation upon archival
When an OpenSpec change is verified and transitioned to the `completed` lifecycle state, the workflow SHALL aggregate the token counts of all completed issues and update a central repository token ledger.

#### Scenario: Archiving a change updates the central ledger
- **WHEN** an issue is completed via `openspec-issue.sh set-lifecycle <issue> completed` or the archive workflow
- **THEN** the workflow SHALL write the aggregated project token summary and per-change breakdown to `openspec/token-usage.json` and a formatted summary in `openspec/token-usage.md`
- **AND** include total input tokens, total output tokens, overall tokens, and total estimated cost.

#### Scenario: Manual aggregation of historical issues
- **WHEN** `openspec-issue.sh aggregate-tokens` is executed
- **THEN** the adapter SHALL parse all open and closed OpenSpec issues in the repository, compute cumulative totals, and regenerate `openspec/token-usage.json` and `openspec/token-usage.md`.

### Requirement: Classified error handling and rollback for token operations
Token recording and aggregation operations SHALL fail explicitly with classified error codes when network, permissions, or structural issues occur, leaving the remote issue and local files in their prior valid state.

#### Scenario: Mutation failure during token recording
- **WHEN** a token update fails during GitHub label assignment or body editing
- **THEN** the adapter SHALL roll back the issue body and labels to their previous valid state
- **AND** report the classified error without claiming success.
