# Proposal

## Why

Developing and validating the BrandyFly Flutter mobile application on a headless Linux mini PC (`bosgame`) requires reliable local execution targets without physical display hardware. We need standardized conventions and automation for booting the hardware-accelerated Android emulator offscreen, streaming it with low latency to a workstation (`garuda`), and deploying cleanly to physical Android devices over USB and local network.

## What Changes

- Introduce headless Android emulator startup automation using `xvfb-run`, host GPU rendering (`-gpu host`), cold boot (`-no-snapshot`), and headless mode (`-no-window`) via `~/bin/start-emulator.sh`.
- Expose a LAN ADB bridge on port 5555 via `socat` to enable direct device streaming to `scrcpy` running on workstation desktops over Wi-Fi/LAN.
- Define explicit runtime target conventions:
  - "run the app": Defaults to the server emulator `brandyfly_test_device` when development runs on the `bosgame` server; falls back to standard local workstation targets when running on desktops/Macs.
  - "run the app on my connected android": Defaults to physical USB connection directly on the `bosgame` server via `~/bin/run-android-device.sh`; supports workstation USB over Wi-Fi/TCP as an alternative.
- Enable autonomous agent-driven visual verification and UI testing via ADB screencap (`exec-out screencap -p`) and input event injection.

## Capabilities

### New Capabilities

- `headless-device-workflows`: Manages headless emulator execution, autonomous UI inspection, and multi-target Android deployment conventions across headless servers and connected workstations.

### Modified Capabilities

None.

## Impact

- **Affected Systems**: Developer toolchain, `AGENTS.md`, `docs/development.md`, and local runner utility scripts in `~/bin/`.
- **Dependencies**: Added `xvfb`, `socat`, `android-sdk-platform-tools-common`, and `android-udev-rules` system packages.
- **Safety / Offline**: No flight-critical algorithms or telemetry processing are altered; ensures deterministic offline verification capabilities before test flights.
