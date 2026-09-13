# BrandyFly Local Run Guidelines

Always follow these guidelines when asked to start the paragliding vario application locally.

## Starting the Mobile App

Run the paragliding vario application on authentic target environments (Android Emulator or physical device on Linux, iOS Simulator on macOS):

- **Command (Android Emulator / Device)**: `flutter run -d android --dart-define=BRANDYFLY_LOCAL_MOCK_FLIGHT_MODE=true`
  - If the emulator is not already running, launch it with: `flutter emulators --launch brandyfly_test_device` or `~/Android/Sdk/emulator/emulator -avd brandyfly_test_device`
- **Command (iOS Simulator on macOS)**: `flutter run -d iPhone --dart-define=BRANDYFLY_LOCAL_MOCK_FLIGHT_MODE=true`
- **Working Directory**: `/home/markus/Projects/private/brandyfly/apps/mobile`
- **Tool Options**:
  - `IsDaemon: true`
  - `RunPersistent: true`
  - `WaitMsBeforeAsync: 10000`

## Active Window / Process Behavior

- If the user actively closes the application window or emulator, the command execution task will finish.
- **DO NOT** restart the application automatically upon window closure/exit unless explicitly requested by the user.

## OpenSpec Workflow Guidelines

In this repository, follow the standard OpenSpec specification-driven change management workflow:

- Use `openspec` / `npx openspec` CLI for managing changes and specifications under `openspec/changes/<change-name>/`.
- Create and validate planning artifacts (`proposal.md`, `specs/`, `design.md`, `tasks.md`) before implementation.
- Validate specs and changes with `npx openspec validate --all --strict`.
- Archive completed changes with `npx openspec archive <change-name>`.

