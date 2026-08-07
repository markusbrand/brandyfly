# Architecture

BrandyFly separates latency-sensitive flight processing from presentation and
online services.

```text
Kotlin / Swift acquisition
          |
          v
  Rust flight_core
    |           |
    v           v
native audio  Flutter snapshots
                  |
                  v
              MapLibre UI
```

The Flutter UI must never be the sole owner of sensor acquisition, audio timing,
or flight-log durability. Native platform adapters normalize lifecycle and
hardware events. The Rust core will own deterministic filtering, derived flight
metrics, and replayable calculations once those contracts are specified.

The Go backend provides optional synchronization and live services. Safety-
critical flight behavior remains local and offline. Large map packages are built
in GitHub Actions and distributed independently from the Raspberry Pi service.

Cross-module contracts belong in `packages/contracts` and are versioned before
multiple producers or consumers depend on them.
