# BrandyFly mobile

Flutter application for Android and iOS. Product capabilities are introduced
through OpenSpec changes; this module currently provides only the app shell.

## Local mock flight mode

Run deterministic mock scenarios on a development laptop with:

```sh
flutter run --dart-define=BRANDYFLY_LOCAL_MOCK_FLIGHT_MODE=true
```

Additional knobs:

- `BRANDYFLY_LOCAL_MOCK_FIXTURE_VERSION`
- `BRANDYFLY_LOCAL_MOCK_SEED`
- `BRANDYFLY_LOCAL_MOCK_CLOCK_STEP_MS`
- `BRANDYFLY_LOCAL_MOCK_START_ISO8601`
- `BRANDYFLY_LOCAL_MOCK_PROVENANCE`

Mock mode is development-only and is rejected in release builds.
