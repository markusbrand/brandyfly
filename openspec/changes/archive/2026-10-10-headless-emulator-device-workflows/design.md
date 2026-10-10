# Design

## Context

See `proposal.md` for motivation. The headless Ubuntu server (`bosgame`) runs without an X11/Wayland display server or attached monitor, but contains an AMD Radeon APU with hardware Vulkan/DRI acceleration. The Android emulator's `-gpu host` mode (gfxstream) requires an active GLX/X11 display context to initialize its host OpenGL/Vulkan translation layers, which is resolved via Xvfb. Remote developer workstations (`garuda`) connect over the local LAN and run Wayland desktop sessions capable of low-latency video decoding.

## Goals / Non-Goals

**Goals:**
- Provide reliable, scriptable lifecycle management for the `brandyfly_test_device` AVD on headless Linux servers.
- Expose ADB on LAN via `socat` to allow `scrcpy` desktop streaming directly across the local network without complex port-forwarding setups.
- Provide targeted execution scripts for both server emulators and physical Android devices.
- Support autonomous agent verification using ADB screencap and input injection.

**Non-Goals:**
- Cloud-based CI emulator farms; this design focuses on the local mini PC server and LAN developer workstations.
- Modifying production Flutter application code, platform channels, or Rust telemetry pipelines.

## Decisions

### Decision 1: Use Xvfb for Offscreen Host GPU Emulation
- **Rationale**: The official Android emulator requires an X11 display context for GLX/EGL initialization when `-gpu host` is specified. `xvfb-run -a` creates an isolated virtual display (:99+) that fulfills the X11 context requirement while letting Mesa/RADV communicate directly with `/dev/dri/renderD128`.
- **Alternatives Considered**:
  - `-gpu swiftshader_indirect`: Dropped per project rules because software rendering causes MapLibre terrain and peak labels to glitch or render in red/green/pink artifacts.
  - Headless without Xvfb: Crashed immediately with `Failed to get EGL display` / `DISPLAY: (null)`.

### Decision 2: Socat TCP Bridge on Port 5555
- **Rationale**: QEMU binds the emulator's ADB daemon strictly to `127.0.0.1:5555`. Using `socat TCP-LISTEN:5555,bind=192.168.0.152,fork,reuseaddr TCP:127.0.0.1:5555` makes the device directly addressable from any machine on the local subnet without needing constant SSH port tunnels.
- **Alternatives Considered**:
  - SSH tunnel (`ssh -L 5555:localhost:5555`): Requires an active terminal on the client and breaks if the SSH session drops.

### Decision 3: Option B as Default for Physical Devices
- **Rationale**: For physical device testing, plugging the phone into the Bosgame mini PC via USB provides direct, deterministic ADB connectivity without Wi-Fi dropouts, IP changes, or dynamic port shifts. Option A (Garuda PC USB + `adb tcpip`) remains fully supported as a remote fallback.

## Risks / Trade-offs

- **[Host Memory Pressure with Minecraft Server]** → Mitigation: Added an 8GB secondary swapfile on the NVMe SSD (total 12GB swap) and capped AVD RAM at 2048MB, preventing kernel OOM killer triggers.
- **[Snapshot Boot Crash with Host GPU]** → Mitigation: Enforced `-no-snapshot` cold boot across all scripts.
