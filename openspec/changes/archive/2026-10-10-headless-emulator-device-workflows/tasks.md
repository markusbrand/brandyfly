# Tasks

## 1. Environment and Toolchain Configuration

- [x] 1.1 Install system packages (`android-sdk-platform-tools-common`, `android-udev-rules`, `xvfb`, `socat`) on Bosgame server and verify `plugdev`, `kvm`, and `render` permissions.
- [x] 1.2 Transfer and configure `brandyfly_test_device` AVD, Android 34 Google APIs x86_64 system image, and emulator binaries to the Bosgame server.
- [x] 1.3 Add 8GB secondary swap file and adjust AVD memory settings to prevent host OOM killer events.

## 2. Script Automation and Bridge Setup

- [x] 2.1 Implement `~/bin/connect-android.sh` to support wireless ADB connections, ICMP ping reachability check, and interactive diagnostics.
- [x] 2.2 Implement `~/bin/start-emulator.sh` to launch `brandyfly_test_device` detached with Xvfb, host GPU, cold boot, and `socat` LAN forwarding on port 5555.
- [x] 2.3 Implement `~/bin/stop-emulator.sh` for clean termination of the emulator and port forwarder.
- [x] 2.4 Implement `~/bin/run-android-device.sh` defaulting to direct USB Android device detection on Bosgame server with authorization prompts.

## 3. Verification and Documentation

- [x] 3.1 Verify headless emulator launch, LAN bridge connectivity from Garuda PC, and `scrcpy` live desktop streaming.
- [x] 3.2 Verify autonomous visual capture (`screencap`) and multimodal UI inspection on running BrandyFly app.
- [x] 3.3 Update workspace developer instructions (`AGENTS.md` and `docs/development.md`) with target decision rules.
