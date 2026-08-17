# BrandyFly mobile

Flutter application shell for Android, iOS, Linux, and Web. Product capabilities are introduced
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

## Desktop preview

From this directory you can run a fast local UI preview on Linux:

```sh
flutter pub get
flutter run -d linux
```

For a browser preview:

```sh
flutter run -d web-server --web-port 8080
```

The current app still renders only the minimal bootstrap shell, but the preview
targets are ready for iterative UI work.
