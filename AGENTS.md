# Workspace Guidelines & OpenSpec Workflow

## Project Overview
BrandyFly is an open-source, local-first paragliding vario and flight computer application.
- **Tech Stack**: Flutter/Dart UI (`apps/mobile`), Rust flight core (`crates/`), Kotlin/Swift native platform adapters, MapLibre/PMTiles, Go backend (`services/`).
- **Core Principles**: Safety-critical flight telemetry, offline-first reliability, low latency, deterministic replay support.
## Running the App & Target Conventions

1. **"run the app" (Default run command)**:
   - **Environment check first**: Check whether running on the headless `bosgame` server (hostname `bosgame`) or a workstation (desktop Linux on Garuda PC / macOS laptop from Red Bull).
   - **On `bosgame` server (Default workflow)**:
     - The default target is the GPU-accelerated Android emulator running directly on the user's Garuda PC workstation (`brandyfly_test_device`).
     - Deploy with `~/bin/deploy-garuda-emulator.sh` (or `~/bin/run-app.sh`), which builds the APK on Bosgame, ensures the Garuda emulator is running via `~/bin/start-emulator.sh` (`ssh garuda ~/bin/start-local-emulator.sh`), transfers the APK, and launches the app on the Garuda desktop.
     - Take autonomous screenshots from Bosgame via:
       `ssh garuda "export PATH=\$HOME/Android/Sdk/platform-tools:\$PATH; adb exec-out screencap -p" > /tmp/screen.png` and inspect with the `read` tool.
   - **On local workstation (Garuda PC)**:
     - Launch the local emulator with `~/bin/start-local-emulator.sh` and run `cd apps/mobile && flutter run -d emulator-5554` (or target Linux desktop directly with `flutter run -d linux`).
   - **On Red Bull Mac laptop (macOS)**:
     - Use the local iOS Simulator or Android emulator (`flutter run -d <simulator/emulator-id>`) or macOS desktop target (`flutter run -d macos`).

2. **"run the app on my connected android"**:
   - Targets the physical Android device.
   - **On `bosgame` server**:
     - **Default: Option B (USB plugged directly into Bosgame Server)**:
       - Plug phone into USB on Bosgame server.
       - Execute `~/bin/run-android-device.sh` (or detect with `adb devices`, filtering out emulators, and run `flutter run -d <usb-serial>`).
       - If unauthorized, prompt to unlock screen and tap "Always allow from this computer".
       - If not detected, check `lsusb` / remind to plug via USB to Bosgame and enable USB Debugging.
     - **Alternative: Option A (Phone plugged into Garuda PC / Wi-Fi)**:
       - If preferred, the phone can stay on Garuda via Wi-Fi: enable TCP with `ssh garuda "adb tcpip 5555"`, connect from Bosgame via `~/bin/connect-android.sh <phone-ip>`, and deploy with `flutter run -d <phone-ip>:5555`.
   - **On local workstation (Garuda / Red Bull Mac)**: Detect local USB/Wi-Fi Android device directly with `flutter run -d <device-id>`.

---

## Git & GitHub Workflow

All development work MUST follow a strict branch-based GitHub workflow:

1. **Automatic Feature Branch Creation**:
   - Before starting work on any new change, task, or feature, automatically create and checkout a dedicated Git branch (e.g., `feature/<change-name>`, `fix/<change-name>`, or matching the OpenSpec change name).
   - **Never work on or commit directly to the `main` or `master` branch.** Always verify you are on a dedicated feature branch before making changes.

2. **No Direct Pushes to Remote Main/Master**:
   - Pushing directly to the remote `main` or `master` branch is strictly prohibited.

3. **Pull Request (PR) Workflow**:
   - Immediately after archiving an OpenSpec change, execute a git commit (`git commit -m "chore(openspec): archive <change-name>"`), push the feature branch to GitHub (`git push -u origin <branch-name>`), and create a GitHub Pull Request associated with the branch targeting `main` (including PR status info and merge state).

4. **Post-Merge Local Synchronization**:
   - Immediately following any successful PR merge, automatically synchronize the local repository with remote `main` (`git fetch origin main --prune && git pull --ff-only origin main` in the main repository and fast-forwarding active worktrees), ensuring the local environment is always completely up-to-date with merged changes.

5. **GitHub Account**:
   - Always use the personal GitHub account `markusbrand` for every GitHub CLI/API operation in this project (PRs, issues, checks, releases). The default `gh` account on this machine is a managed enterprise account that cannot access this repository.
   - Run `gh` commands with that account's token without switching the global active account, e.g. `GH_TOKEN=$(gh auth token --user markusbrand) gh pr create ...`.

---

## Change Management: OpenSpec Workflow

All non-trivial changes, feature additions, bug fixes, and architectural adjustments in this repository MUST follow the **OpenSpec specification-driven change management** workflow using the integrated OpenSpec skills and CLI (`npx openspec` or `openspec`).

### Core Lifecycle

1. **Explore & Ideate (Optional)**:
   - Use the `openspec-explore` skill or `/opsx-explore` when clarifying requirements or investigating problems.

2. **Propose & Plan (Strict Planning Boundary)**:
   - Use `openspec-propose` (or `openspec-new-change` / `/opsx-propose`) to scaffold changes in `openspec/changes/<change-name>/`.
   - Generates: `proposal.md`, delta specifications under `specs/`, `design.md`, and `tasks.md`.
   - **Crucial**: The propose phase authorizes planning only. Do NOT modify source code during this step. Present the artifacts and wait for explicit user confirmation.

3. **Apply & Implement**:
   - Ensure a dedicated feature branch exists and is checked out before editing source code.
   - Use `openspec-apply-change` (or `/opsx-apply`) to systematically implement tasks defined in `tasks.md`.
   - Follow project standards, keeping sensor/audio loops off the Flutter main thread and preserving offline capabilities.

4. **Verify & Validate**:
   - Use `openspec-verify-change` and run `npx openspec validate --all --strict` to ensure all requirements, scenarios, and tests pass.

5. **Archive & Sync**:
   - **Mandatory Pre-requisite**: ALWAYS run verification (`openspec-verify-change` / `npx openspec validate --all --strict`) and confirm all checks pass BEFORE running archive. Never execute `openspec archive` without verifying first.
   - Use `openspec-archive-change` (or `/opsx-archive`) to promote delta specs to main `openspec/specs/` and archive the change.
   - Use `openspec-sync-specs` if specs need syncing prior to archiving.

6. **Post-Archive Commit, Push & Pull Request**:
   - Immediately following `openspec archive`, open the newly promoted spec file in `openspec/specs/` and replace the `TBD` placeholder in the `## Purpose` section with a proper description.
   - Run `npx openspec validate --all --strict` one final time to ensure the promoted spec is valid.
   - Commit all remaining changes (`git commit -m "chore(openspec): archive <change-name>"`).
   - Push the feature branch to the GitHub remote repository (`git push -u origin <branch-name>`).
   - Create a GitHub Pull Request (using `gh pr create` or GitHub CLI/API) targeting `main` (or `master`). Include PR details and status (whether pending review or already merged).

---

## OpenSpec CLI Reference

Prefer the `--json` flag when running CLI queries programmatically:

| Command | Purpose |
|---|---|
| `npx openspec list --json` | List active changes and specs |
| `npx openspec status [--change <name>] --json` | Check artifact completion progress |
| `npx openspec instructions <artifact> --change <name> --json` | Retrieve schema-guided generation instructions |
| `npx openspec validate [--all] [--strict] --json` | Validate change artifacts and specs |
| `npx openspec archive <change> --json --yes` | Archive completed change |
