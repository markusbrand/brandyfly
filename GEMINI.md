# BrandyFly Local Run Guidelines

Always follow these guidelines when asked to start the paragliding vario application locally.

## Starting the Mobile App

Run the following command to start the Flutter mobile app in local mock flight mode on the Linux desktop:

- **Command**: `flutter run -d linux --dart-define=BRANDYFLY_LOCAL_MOCK_FLIGHT_MODE=true`
- **Working Directory**: `/home/markus/Projects/brandyfly/apps/mobile`
- **Tool Options**:
  - `BypassSandbox: true`
  - `IsDaemon: true`
  - `RunPersistent: true`
  - `WaitMsBeforeAsync: 10000`

## Active Window Close Behavior

- If the user actively closes the application window, the command execution task will finish.
- **DO NOT** restart the application automatically upon window closure/exit unless explicitly requested by the user.

## OpenSpec & GitHub Issue Workflow Guidelines

In this repository, GitHub issues are the sole authoritative change store for all OpenSpec operations (see `openspec/specs/github-issue-change-management/spec.md`).

- **ALWAYS** use the `./tools/openspec-issue/openspec-issue.sh` adapter script for all OpenSpec change lifecycle actions (propose, list, read, update, set-lifecycle, complete).
- **NEVER** write or commit local per-change markdown directories under `openspec/changes/`.
- When creating or capturing a new change proposal, ALWAYS create the corresponding GitHub issue directly via `./tools/openspec-issue/openspec-issue.sh create`.

