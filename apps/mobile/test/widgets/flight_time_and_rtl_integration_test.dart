import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brandyfly/data/repositories/telemetry_repository.dart';
import 'package:brandyfly/domain/models/size_tier.dart';
import 'package:brandyfly/domain/models/ui_config.dart';
import 'package:brandyfly/domain/models/widget_type.dart';
import 'package:brandyfly/services/flight_replay_service.dart';
import 'package:brandyfly/services/igc_parser_service.dart';
import 'package:brandyfly/ui/features/flight_canvas/views/widget_slot.dart';
import 'package:brandyfly/ui/features/instruments/views/flight_time_widget.dart';
import 'package:brandyfly/ui/features/instruments/views/return_glide_widget.dart';

Widget _buildTestHost({
  required Widget child,
  double width = 400,
  double height = 240,
}) {
  return MaterialApp(
    home: Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: SizedBox(
          width: width,
          height: height,
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  group('FlightTime and ReturnGlide Replay Integration Tests', () {
    late String igcContent;
    late FlightReplayService replayService;
    late TelemetryRepository telemetryRepo;

    setUpAll(() {
      var file = File('assets/sample_flights/Krippenstein-Aussee.IGC');
      if (!file.existsSync()) {
        file = File('apps/mobile/assets/sample_flights/Krippenstein-Aussee.IGC');
      }
      expect(
        file.existsSync(),
        isTrue,
        reason: 'Sample IGC file must exist at ${file.path}',
      );
      igcContent = file.readAsStringSync();
    });

    setUp(() {
      final flight = const IGCParserService().parseIgc(igcContent);
      replayService = FlightReplayService(flight: flight);
      telemetryRepo = TelemetryRepository(replayService: replayService);
      telemetryRepo.setReplayActive(true);
    });

    tearDown(() {
      telemetryRepo.dispose();
      replayService.dispose();
    });

    testWidgets(
      'both widgets render accurately during active IGC flight replay across regular, compact, and tiny tiers without overflow',
      (tester) async {
        const ftPlacement = WidgetPlacementModel(
          id: 'ft_slot',
          type: WidgetType.flightTime,
          x: 0,
          y: 0,
          w: 8,
          h: 4,
        );

        const rtlPlacement = WidgetPlacementModel(
          id: 'rtl_slot',
          type: WidgetType.returnGlide,
          x: 0,
          y: 4,
          w: 8,
          h: 4,
        );

        // Track any Flutter layout errors (such as RenderFlex overflow)
        final errors = <FlutterErrorDetails>[];
        final previousOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          errors.add(details);
          previousOnError?.call(details);
        };

        try {
          // 1. Initial takeoff point verification
          await tester.pumpWidget(
            _buildTestHost(
              child: Column(
                children: [
                  Expanded(
                    child: FlightWidgetContent(
                      model: ftPlacement,
                      telemetry: telemetryRepo.telemetry,
                      tier: SizeTier.regular,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: FlightWidgetContent(
                      model: rtlPlacement,
                      telemetry: telemetryRepo.telemetry,
                      tier: SizeTier.regular,
                    ),
                  ),
                ],
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(FlightTimeWidget), findsOneWidget);
          expect(find.byType(ReturnGlideWidget), findsOneWidget);
          expect(find.text('00:00'), findsOneWidget);
          expect(errors, isEmpty);

          // 2. Advance replay through active flight milestones (50, 200, 600, 1500 fixes)
          final checkpoints = [50, 200, 600, 1500];
          for (final fixIndex in checkpoints) {
            replayService.seekTo(fixIndex);
            await tester.pumpAndSettle();

            final telemetry = telemetryRepo.telemetry.value;
            expect(telemetry.takeoffTime, isNotNull);
            expect(telemetry.flightDuration, isNotNull);
            expect(telemetry.flightDuration!.inSeconds, greaterThan(0));
            expect(telemetry.rtlDistanceMeters, isNotNull);
            expect(telemetry.rtlDistanceMeters!, greaterThan(0.0));

            // Verify both widgets display live values without RenderFlex overflow
            expect(find.byType(FlightTimeWidget), findsOneWidget);
            expect(find.byType(ReturnGlideWidget), findsOneWidget);
            expect(errors, isEmpty);
          }

          // 3. Verify compact tier presentation under constrained dimensions
          await tester.pumpWidget(
            _buildTestHost(
              width: 180,
              height: 120,
              child: Column(
                children: [
                  Expanded(
                    child: FlightWidgetContent(
                      model: ftPlacement,
                      telemetry: telemetryRepo.telemetry,
                      tier: SizeTier.compact,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: FlightWidgetContent(
                      model: rtlPlacement,
                      telemetry: telemetryRepo.telemetry,
                      tier: SizeTier.compact,
                    ),
                  ),
                ],
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(errors, isEmpty);

          // 4. Verify tiny tier presentation under micro slot dimensions
          await tester.pumpWidget(
            _buildTestHost(
              width: 100,
              height: 60,
              child: Row(
                children: [
                  Expanded(
                    child: FlightWidgetContent(
                      model: ftPlacement,
                      telemetry: telemetryRepo.telemetry,
                      tier: SizeTier.tiny,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: FlightWidgetContent(
                      model: rtlPlacement,
                      telemetry: telemetryRepo.telemetry,
                      tier: SizeTier.tiny,
                    ),
                  ),
                ],
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(errors, isEmpty);
        } finally {
          FlutterError.onError = previousOnError;
        }
      },
    );

    testWidgets('cleans up replay and telemetry subscriptions cleanly on unmount', (
      tester,
    ) async {
      const ftPlacement = WidgetPlacementModel(
        id: 'ft_slot_cleanup',
        type: WidgetType.flightTime,
        x: 0,
        y: 0,
        w: 4,
        h: 4,
      );

      await tester.pumpWidget(
        _buildTestHost(
          child: FlightWidgetContent(
            model: ftPlacement,
            telemetry: telemetryRepo.telemetry,
            tier: SizeTier.regular,
          ),
        ),
      );
      await tester.pumpAndSettle();

      replayService.advance(10);
      await tester.pump();

      // Unmount
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      // Advancing replay after unmount should not trigger exceptions or rebuilds
      expect(() => replayService.advance(10), returnsNormally);
    });
  });
}
