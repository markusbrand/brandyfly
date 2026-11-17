import 'package:brandyfly/domain/models/sensor_readiness.dart';
import 'package:brandyfly/widgets/flight/sensor_alert_liner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SensorAlertLiner Widget Tests', () {
    testWidgets('renders missing barometer and GPS state without close button', (tester) async {
      const state = SensorReadinessState(
        barometerStatus: SensorDomainStatus.hardwareMissing,
        gpsStatus: SensorDomainStatus.hardwareMissing,
      );

      var settingsTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SensorAlertLiner(
              state: state,
              onOpenSettings: () => settingsTapped = true,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('sensor_alert_liner')), findsOneWidget);
      expect(find.textContaining('No barometer'), findsOneWidget);
      expect(find.textContaining('GPS missing'), findsOneWidget);
      // Non-dismissable: no close icon button
      expect(find.byIcon(Icons.close), findsNothing);

      final settingsBtn = find.byKey(const Key('sensor_alert_liner_settings_btn'));
      expect(settingsBtn, findsOneWidget);
      await tester.tap(settingsBtn);
      expect(settingsTapped, isTrue);
    });

    testWidgets('hides automatically when readiness transitions to ready and re-appears on disconnect', (tester) async {
      var currentState = const SensorReadinessState(
        barometerStatus: SensorDomainStatus.hardwareMissing,
        gpsStatus: SensorDomainStatus.availableReady,
      );

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    SensorAlertLiner(state: currentState),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          currentState = const SensorReadinessState(
                            barometerStatus: SensorDomainStatus.availableReady,
                            gpsStatus: SensorDomainStatus.availableReady,
                            externalVarioConnected: true,
                          );
                        });
                      },
                      child: const Text('Connect Vario'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          currentState = const SensorReadinessState(
                            barometerStatus: SensorDomainStatus.disconnected,
                            gpsStatus: SensorDomainStatus.availableReady,
                          );
                        });
                      },
                      child: const Text('Disconnect Vario'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );

      expect(find.byKey(const Key('sensor_alert_liner')), findsOneWidget);
      expect(find.textContaining('No barometer'), findsOneWidget);

      await tester.tap(find.text('Connect Vario'));
      await tester.pump();
      expect(find.byKey(const Key('sensor_alert_liner')), findsNothing);

      await tester.tap(find.text('Disconnect Vario'));
      await tester.pump();
      expect(find.byKey(const Key('sensor_alert_liner')), findsOneWidget);
      expect(find.textContaining('Bluetooth vario disconnected'), findsOneWidget);
    });

    testWidgets('hides in mock flight mode and replay mode', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SensorAlertLiner(
                  state: SensorReadinessState(
                    barometerStatus: SensorDomainStatus.hardwareMissing,
                    gpsStatus: SensorDomainStatus.hardwareMissing,
                    isMockFlightMode: true,
                  ),
                ),
                SensorAlertLiner(
                  state: SensorReadinessState(
                    barometerStatus: SensorDomainStatus.hardwareMissing,
                    gpsStatus: SensorDomainStatus.hardwareMissing,
                    isReplayActive: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('sensor_alert_liner')), findsNothing);
    });
  });
}
