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

## OpenSpec Workflow Guidelines

In this repository, follow the standard OpenSpec specification-driven change management workflow:

- Use `openspec` / `npx openspec` CLI for managing changes and specifications under `openspec/changes/<change-name>/`.
- Create and validate planning artifacts (`proposal.md`, `specs/`, `design.md`, `tasks.md`) before implementation.
- Validate specs and changes with `npx openspec validate --all --strict`.
- Archive completed changes with `npx openspec archive <change-name>`.

