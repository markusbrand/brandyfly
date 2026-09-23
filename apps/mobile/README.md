# BrandyFly mobile

Flutter application shell for Android, iOS, Linux, and Web. Product capabilities are introduced
through OpenSpec changes; this module currently provides only the app shell.

## Running the app

The default container for running the app is the **Android emulator**. The map
rendering (MapLibre) is not supported on the Linux desktop target, so always run
on an Android emulator (or a physical Android/iOS device) for an authentic
environment.

From this directory:

```sh
flutter pub get
flutter emulators --launch brandyfly_test_device
flutter run -d android
```

## Local mock flight mode

Run deterministic mock scenarios on a development laptop with:

```sh
flutter run -d android --dart-define=BRANDYFLY_LOCAL_MOCK_FLIGHT_MODE=true
```

Additional knobs:

- `BRANDYFLY_LOCAL_MOCK_FIXTURE_VERSION`
- `BRANDYFLY_LOCAL_MOCK_SEED`
- `BRANDYFLY_LOCAL_MOCK_CLOCK_STEP_MS`
- `BRANDYFLY_LOCAL_MOCK_START_ISO8601`
- `BRANDYFLY_LOCAL_MOCK_PROVENANCE`

Mock mode is development-only and is rejected in release builds.

## Non-map previews

A raw UI preview without map support can be run on the Linux desktop:

```sh
flutter run -d linux
```

But note MapLibre is not supported on this platform, so the map area of the
flight screen will throw `UnsupportedError: MapLibre is not supported on this
platform.` Use the Android emulator instead.

For a browser preview:

```sh
flutter run -d web-server --web-port 8080
```

The current app still renders only the minimal bootstrap shell, but the preview
targets are ready for iterative UI work.
