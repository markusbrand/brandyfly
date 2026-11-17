import 'dart:async';

import 'package:brandyfly/data/repositories/telemetry_repository.dart';
import 'package:brandyfly/domain/models/sensor_readiness.dart';
import 'package:brandyfly/main.dart';
import 'package:brandyfly/services/airspace_service.dart';
import 'package:brandyfly/services/sensor_readiness_service.dart';
import 'package:brandyfly/services/telemetry/telemetry_source.dart';
import 'package:brandyfly/services/telemetry/telemetry_types.dart';
import 'package:brandyfly/widgets/flight/airspace_warning_banner_hud.dart';
import 'package:brandyfly/widgets/flight/sensor_alert_liner.dart';
import 'package:brandyfly_native/brandyfly_native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeBleSource implements ITelemetrySource {
  @override
  TelemetrySourceType get sourceType => TelemetrySourceType.ble;

  @override
  String get name => 'SkyDrop 1';

  final _ctrl = StreamController<TelemetrySnapshot>.broadcast();
  final _rawCtrl = StreamController<dynamic>.broadcast();

  @override
  Stream<TelemetrySnapshot> get telemetryStream => _ctrl.stream;

  @override
  Stream<dynamic> get rawSensorStream => _rawCtrl.stream;

  @override
  bool get isRunning => true;

  @override
  bool get isPaused => false;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> start() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> stop() async {}

  void emit(TelemetrySnapshot s) => _ctrl.add(s);

  @override
  void dispose() {
    _ctrl.close();
    _rawCtrl.close();
  }
}

class _FakeNativeNoBaro extends BrandyflyNative {
  @override
  Future<String?> getPlatformVersion() async => 'Android 14';

  @override
  Future<NativeSensorCapabilities> getSensorCapabilities() async =>
      const NativeSensorCapabilities(
        hasBarometer: false,
        hasGps: true,
        locationEnabled: true,
        locationPermissionGranted: true,
        bluetoothAvailable: true,
      );
}

void main() {
  const viewports = [
    Size(390, 844), // Portrait phone
    Size(844, 390), // Landscape phone
    Size(1280, 800), // Tablet
  ];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SensorAlertLiner Layout & Stacking Tests', () {
    for (final viewport in viewports) {
      testWidgets(
        'renders without overflow or overlap on ${viewport.width.toInt()}x${viewport.height.toInt()}',
        (tester) async {
          tester.view.physicalSize = viewport;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            BrandyFlyApp(
              config: MockFlightModeConfig(
                enabled: false,
                fixtureVersion: 'mock-flight-v1',
                seed: 7,
                logicalClockStep: const Duration(seconds: 1),
                startTime: DateTime.utc(2026, 11, 16),
                provenance: 'synthetic-anonymized',
              ),
              native: _FakeNativeNoBaro(),
            ),
          );

          await tester.pump();
          await tester.pump();
          await tester.pump();

          final linerFinder = find.byKey(const Key('sensor_alert_liner'));
          expect(linerFinder, findsOneWidget);

          final grabHandleFinder = find.byKey(const Key('top_nav_grab_handle'));
          expect(grabHandleFinder, findsOneWidget);

          final linerRect = tester.getRect(linerFinder);
          final grabRect = tester.getRect(grabHandleFinder);
          expect(linerRect.bottom, lessThanOrEqualTo(grabRect.top + 0.01));

          // Settings quick action on the liner remains tappable and opens Settings
          final settingsBtn =
              find.byKey(const Key('sensor_alert_liner_settings_btn'));
          expect(settingsBtn, findsOneWidget);
          await tester.tap(settingsBtn);
          await tester.pumpAndSettle();
          expect(find.text('Application Settings'), findsOneWidget);
          // Liner stays visible even on Settings until sensors are ready
          expect(linerFinder, findsOneWidget);
        },
      );
    }

    testWidgets('stacks cleanly above AirspaceWarningBannerHUD without overlap',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              padding: EdgeInsets.only(top: 24),
            ),
            child: Builder(
              builder: (context) => Column(
                children: [
                  const SensorAlertLiner(
                    state: SensorReadinessState(
                      barometerStatus: SensorDomainStatus.hardwareMissing,
                      gpsStatus: SensorDomainStatus.waitingForFix,
                    ),
                  ),
                  Expanded(
                    child: MediaQuery.removePadding(
                      context: context,
                      removeTop: true,
                      child: const Scaffold(
                        body: Stack(
                          children: [
                            Positioned(
                              top: 8,
                              left: 16,
                              right: 16,
                              child: AirspaceWarningBannerHUD(
                                proximity: AirspaceProximityState(
                                  alertLevel: AirspaceAlertLevel.warning,
                                  airspaceName: 'INNSBRUCK CTR',
                                  airspaceClass: 'CTR',
                                  horizontalSeparationM: 250,
                                  verticalSeparationM: 40,
                                  total3dDistanceM: 253,
                                  isInsideHorizontal: false,
                                  isInsideVertical: false,
                                  floorMslM: 600,
                                  ceilingMslM: 2000,
                                  forwardIntersectionDistanceM: 800,
                                  forwardIntersectionTimeS: 60,
                                  willPenetrateGlideSlope: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final linerRect =
          tester.getRect(find.byKey(const Key('sensor_alert_liner')));
      final airspaceRect =
          tester.getRect(find.byType(AirspaceWarningBannerHUD));
      expect(linerRect.bottom, lessThanOrEqualTo(airspaceRect.top));
    });

    testWidgets(
      'BrandyFlyApp clears liner when Bluetooth vario streams and restores on disconnect',
      (tester) async {
        await tester.pumpWidget(
          BrandyFlyApp(
            config: MockFlightModeConfig(
              enabled: false,
              fixtureVersion: 'mock-flight-v1',
              seed: 7,
              logicalClockStep: const Duration(seconds: 1),
              startTime: DateTime.utc(2026, 11, 16),
              provenance: 'synthetic-anonymized',
            ),
            native: _FakeNativeNoBaro(),
          ),
        );

        await tester.pump();
        await tester.pump();
        await tester.pump();

        expect(find.byKey(const Key('sensor_alert_liner')), findsOneWidget);

        final liveCtx = tester.element(find.byType(Scaffold).first);
        final telemetryRepo =
            Provider.of<TelemetryRepository>(liveCtx, listen: false);
        final readiness =
            Provider.of<SensorReadinessService>(liveCtx, listen: false);

        final bleSource = _FakeBleSource();
        addTearDown(bleSource.dispose);
        telemetryRepo.attachSource(bleSource);
        readiness.updateExternalVarioState(
          ExternalVarioConnectionState.connected,
        );
        bleSource.emit(
          TelemetrySnapshot(
            timestamp: DateTime.now(),
            altitude: 1450,
            pressureHpa: 851.0,
            vario: 1.4,
            speed: 38.0,
            heading: 90.0,
            latitude: 47.2692,
            longitude: 11.4041,
          ),
        );

        await tester.pump();
        await tester.pump();
        expect(find.byKey(const Key('sensor_alert_liner')), findsNothing);

        readiness.updateExternalVarioState(
          ExternalVarioConnectionState.disconnected,
        );
        await tester.pump();
        expect(find.byKey(const Key('sensor_alert_liner')), findsOneWidget);
      },
    );
  });
}
