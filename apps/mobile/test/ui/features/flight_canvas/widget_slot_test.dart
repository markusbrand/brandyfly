import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brandyfly/domain/models/cockpit_telemetry.dart';
import 'package:brandyfly/domain/models/size_tier.dart';
import 'package:brandyfly/domain/models/ui_config.dart';
import 'package:brandyfly/domain/models/widget_type.dart';
import 'package:brandyfly/ui/core/rebuild_probe.dart';
import 'package:brandyfly/ui/features/flight_canvas/views/widget_slot.dart';
import 'package:brandyfly/ui/features/instruments/views/flight_time_widget.dart';
import 'package:brandyfly/ui/features/instruments/views/return_glide_widget.dart';

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 320,
          height: 180,
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  setUp(() {
    RebuildProbe.enabled = true;
    RebuildProbe.reset();
  });

  tearDown(() {
    RebuildProbe.enabled = false;
    RebuildProbe.reset();
  });

  group('WidgetSlot FlightWidgetContent flightTime wiring', () {
    const model = WidgetPlacementModel(
      id: 'ft_slot',
      type: WidgetType.flightTime,
      x: 0,
      y: 0,
      w: 4,
      h: 4,
    );

    testWidgets('renders FlightTimeWidget in standby mode initially', (
      tester,
    ) async {
      final notifier = ValueNotifier<CockpitTelemetry>(
        const CockpitTelemetry(hasSource: true),
      );

      await tester.pumpWidget(
        _host(
          FlightWidgetContent(
            model: model,
            telemetry: notifier,
            tier: SizeTier.regular,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FlightTimeWidget), findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);
      expect(find.text('STANDBY'), findsOneWidget);
    });

    testWidgets('updates flight duration and airborne badge when airborne', (
      tester,
    ) async {
      final takeoff = DateTime(2026, 6, 15, 14, 0);
      final notifier = ValueNotifier<CockpitTelemetry>(
        CockpitTelemetry(
          hasSource: true,
          takeoffTime: takeoff,
          flightDuration: const Duration(minutes: 15, seconds: 30),
        ),
      );

      await tester.pumpWidget(
        _host(
          FlightWidgetContent(
            model: model,
            telemetry: notifier,
            tier: SizeTier.regular,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('15:30'), findsOneWidget);
      expect(find.text('AIRBORNE'), findsOneWidget);
      expect(find.text('TAKEOFF 14:00'), findsOneWidget);
    });

    testWidgets('granular selector ignores unrelated telemetry updates (altitude/speed/vario)', (
      tester,
    ) async {
      RebuildProbe.reset();
      final takeoff = DateTime(2026, 6, 15, 14, 0);
      final notifier = ValueNotifier<CockpitTelemetry>(
        CockpitTelemetry(
          hasSource: true,
          takeoffTime: takeoff,
          flightDuration: const Duration(minutes: 5, seconds: 12),
          altitude: 1200,
          speed: 35,
          climb: 1.2,
        ),
      );

      await tester.pumpWidget(
        _host(
          FlightWidgetContent(
            model: model,
            telemetry: notifier,
            tier: SizeTier.regular,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final ticksBefore = RebuildProbe.count('instrument:ft_slot');
      expect(ticksBefore, greaterThan(0));

      // Emit high-frequency sensor updates that don't change flight duration
      notifier.value = notifier.value.copyWith(
        altitude: 1205.5,
        speed: 38.2,
        climb: 2.1,
      );
      await tester.pump();

      final ticksAfterSensorUpdate = RebuildProbe.count('instrument:ft_slot');
      expect(ticksAfterSensorUpdate, equals(ticksBefore));

      // Now update flight duration by 1 second
      notifier.value = notifier.value.copyWith(
        flightDuration: const Duration(minutes: 5, seconds: 13),
      );
      await tester.pump();

      final ticksAfterDurationTick = RebuildProbe.count('instrument:ft_slot');
      expect(ticksAfterDurationTick, equals(ticksBefore + 1));
      expect(find.text('05:13'), findsOneWidget);
    });
  });

  group('WidgetSlot FlightWidgetContent returnGlide wiring', () {
    const model = WidgetPlacementModel(
      id: 'rtl_slot',
      type: WidgetType.returnGlide,
      x: 0,
      y: 0,
      w: 6,
      h: 4,
    );

    testWidgets('renders ReturnGlideWidget in standby mode initially', (
      tester,
    ) async {
      final notifier = ValueNotifier<CockpitTelemetry>(
        const CockpitTelemetry(hasSource: true),
      );

      await tester.pumpWidget(
        _host(
          FlightWidgetContent(
            model: model,
            telemetry: notifier,
            tier: SizeTier.regular,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ReturnGlideWidget), findsOneWidget);
      expect(find.text('---'), findsWidgets);
      expect(find.text('STANDBY'), findsOneWidget);
    });

    testWidgets('renders active RTL metrics when airborne', (
      tester,
    ) async {
      final notifier = ValueNotifier<CockpitTelemetry>(
        const CockpitTelemetry(
          hasSource: true,
          rtlDistanceMeters: 4800,
          rtlRequiredGlide: 6.2,
          rtlAltitudeMarginMeters: 450,
          rtlBearingDegrees: 142,
          heading: 140,
        ),
      );

      await tester.pumpWidget(
        _host(
          FlightWidgetContent(
            model: model,
            telemetry: notifier,
            tier: SizeTier.regular,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('6.2'), findsOneWidget);
      expect(find.text('REQ L/D'), findsOneWidget);
      expect(find.text('DIST 4.8 km'), findsOneWidget);
      expect(find.text('ALT +450 m'), findsOneWidget);
      expect(find.text('142°'), findsOneWidget);
      expect(find.text('AIRBORNE'), findsOneWidget);
    });

    testWidgets('displays below launch state when altitude margin is negative', (
      tester,
    ) async {
      final notifier = ValueNotifier<CockpitTelemetry>(
        const CockpitTelemetry(
          hasSource: true,
          rtlDistanceMeters: 2500,
          rtlRequiredGlide: null,
          rtlAltitudeMarginMeters: -120,
          rtlBearingDegrees: 180,
        ),
      );

      await tester.pumpWidget(
        _host(
          FlightWidgetContent(
            model: model,
            telemetry: notifier,
            tier: SizeTier.regular,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('---'), findsWidgets);
      expect(find.text('BELOW LAUNCH'), findsOneWidget);
      expect(find.text('ALT -120 m'), findsOneWidget);
    });

    testWidgets('granular selector ignores updates that do not change rounded RTL values', (
      tester,
    ) async {
      RebuildProbe.reset();
      final notifier = ValueNotifier<CockpitTelemetry>(
        const CockpitTelemetry(
          hasSource: true,
          rtlDistanceMeters: 4800.2,
          rtlRequiredGlide: 6.22,
          rtlAltitudeMarginMeters: 450.1,
          rtlBearingDegrees: 142.1,
          heading: 140.0,
          climb: 1.2,
          speed: 35.0,
        ),
      );

      await tester.pumpWidget(
        _host(
          FlightWidgetContent(
            model: model,
            telemetry: notifier,
            tier: SizeTier.regular,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final ticksBefore = RebuildProbe.count('instrument:rtl_slot');
      expect(ticksBefore, greaterThan(0));

      // Sensor updates that don't change rounded RTL values
      notifier.value = notifier.value.copyWith(
        climb: 2.5,
        speed: 40.0,
        rtlDistanceMeters: 4800.3,
        rtlRequiredGlide: 6.24,
      );
      await tester.pump();

      final ticksAfterMinor = RebuildProbe.count('instrument:rtl_slot');
      expect(ticksAfterMinor, equals(ticksBefore));

      // Sensor update that changes distance
      notifier.value = notifier.value.copyWith(
        rtlDistanceMeters: 4850.0,
      );
      await tester.pump();

      final ticksAfterDistanceChange = RebuildProbe.count('instrument:rtl_slot');
      expect(ticksAfterDistanceChange, equals(ticksBefore + 1));
    });
  });
}
