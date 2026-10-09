# Verification: live-thermal-assistant-telemetry-coupling

## Automated

| Check | Result |
|---|---|
| `cargo fmt --all --check`, `cargo clippy --workspace --all-targets -- -D warnings` | clean |
| `cargo test --workspace` (incl. fixture freshness `checked_in_fixtures_match_reference_output`) | pass |
| `cd apps/mobile && flutter analyze` | no issues |
| `cd apps/mobile && flutter test` | 609 pass |
| Rust/Dart parity (`test/domain/thermal_assistant_parity_test.dart`, 6 golden fixtures) | pass; mutation (wind EMA alpha 0.6→0.5) detected |
| Replay determinism and seek (`test/data/replay_thermal_tracker_test.dart`) | 300 random seeks equal continuous replay; backward seek reprocesses ≤ 60 points; mutation (restore without clone) detected |
| Honest wind guard (`test/data/no_fabricated_wind_test.dart`) | pass; detects 22 fabricated-wind sites on the pre-change code |
| Benchmark (`test/perf/thermal_assistant_benchmark_test.dart`, 1 h @ 10 Hz) | 9.2 µs/sample mean (budget 1 ms); core ≤ 601, track ≤ 301 samples |
| `npx openspec validate --all --strict` | pass |

## Manual (Android emulator `brandyfly_test_device`, `-gpu host -no-snapshot`, mock flight mode)

- Glide: wind widget shows **NO ESTIMATE**; thermal map renders no bubbles and no demo data.
- Thermal with simulated wind 18 km/h from 280°: automatic switch to the Thermaling screen; live bubble trail rendered; wind estimate **18.0 km/h, 280°** after ~65 s of circling.
- Glide again (fresh app data): `[ScreenAutoSwitch] switching to thermaling` on entry and `switching to normal_flight` on exit; track cleared; wind retained; map track shows the drifted circles.
- Exiting the thermal after ~50 s (fewer than two complete turns after detection) correctly leaves wind at NO ESTIMATE.

Issues found on device and fixed during verification:
- Track bubbles at 4 Hz rendered as a solid band → track window limited to 1 Hz.
- Automatic screen switches were persisted as start screen → automatic switches are no longer persisted (`LayoutRepository.replace(persist: false)`).

## Limitations

- Linux desktop: app launches, but map slots fail with the pre-existing "MapLibre is not supported on this platform" error (documented in `docs/development.md`); no desktop screenshots were captured.
- No real-device flight yet: circling detection with noisy phone GPS heading must pass a real-device release gate (Android + iOS) before the thermal assistant is advertised as flight-ready.
- The audio vario path is independent of the thermal assistant by construction (separate vario stream); there is no dedicated test asserting audio timing under thermal assistant load.
