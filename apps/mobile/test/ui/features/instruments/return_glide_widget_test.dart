import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brandyfly/domain/models/size_tier.dart';
import 'package:brandyfly/ui/features/instruments/views/return_glide_widget.dart';

void main() {
  group('ReturnGlideWidget unit and widget tests', () {
    test('formatGlide formats glide ratio and below-launch fallback', () {
      expect(ReturnGlideWidget.formatGlide(null), '---');
      expect(ReturnGlideWidget.formatGlide(6.23), '6.2');
      expect(
        ReturnGlideWidget.formatGlide(6.23, isBelowLaunch: true),
        '---',
      );
    });

    test('formatDistance formats meters and kilometers', () {
      expect(ReturnGlideWidget.formatDistance(null), '---');
      expect(ReturnGlideWidget.formatDistance(0), '0 m');
      expect(ReturnGlideWidget.formatDistance(450), '450 m');
      expect(ReturnGlideWidget.formatDistance(999), '999 m');
      expect(ReturnGlideWidget.formatDistance(1000), '1.0 km');
      expect(ReturnGlideWidget.formatDistance(4820), '4.8 km');
      expect(ReturnGlideWidget.formatDistance(12500), '12.5 km');
    });

    test('formatAltitudeMargin formats positive, zero, and negative margins', () {
      expect(ReturnGlideWidget.formatAltitudeMargin(null), '---');
      expect(ReturnGlideWidget.formatAltitudeMargin(0), '+0 m');
      expect(ReturnGlideWidget.formatAltitudeMargin(450.4), '+450 m');
      expect(ReturnGlideWidget.formatAltitudeMargin(-120.2), '-120 m');
    });

    test('formatBearing formats bearing degrees within [0, 360)', () {
      expect(ReturnGlideWidget.formatBearing(null), '---');
      expect(ReturnGlideWidget.formatBearing(0), '0°');
      expect(ReturnGlideWidget.formatBearing(142.4), '142°');
      expect(ReturnGlideWidget.formatBearing(360), '0°');
      expect(ReturnGlideWidget.formatBearing(-90), '270°');
    });

    testWidgets('renders standby mode when pre-takeoff', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 250,
                height: 150,
                child: ReturnGlideWidget(
                  tier: SizeTier.regular,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('---'), findsWidgets);
      expect(find.text('STANDBY'), findsOneWidget);
      expect(find.text('RETURN TO LAUNCH'), findsOneWidget);
    });

    testWidgets('renders regular tier with required glide, distance, margin and bearing', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 280,
                height: 160,
                child: ReturnGlideWidget(
                  requiredGlide: 6.2,
                  distanceMeters: 4800,
                  altitudeMarginMeters: 450,
                  bearingDegrees: 142,
                  gliderHeadingDegrees: 130,
                  tier: SizeTier.regular,
                ),
              ),
            ),
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

    testWidgets('renders below launch state with warning badge and --- glide', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 280,
                height: 160,
                child: ReturnGlideWidget(
                  requiredGlide: null,
                  distanceMeters: 3200,
                  altitudeMarginMeters: -120,
                  bearingDegrees: 180,
                  tier: SizeTier.regular,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('---'), findsWidgets);
      expect(find.text('BELOW LAUNCH'), findsOneWidget);
      expect(find.text('ALT -120 m'), findsOneWidget);
    });

    testWidgets('renders compact tier correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 140,
                height: 70,
                child: ReturnGlideWidget(
                  requiredGlide: 7.5,
                  distanceMeters: 3200,
                  altitudeMarginMeters: 300,
                  tier: SizeTier.compact,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('7.5'), findsOneWidget);
      expect(find.text('L/D'), findsOneWidget);
      expect(find.text('RTL'), findsOneWidget);
      expect(find.text('3.2 km'), findsOneWidget);
    });

    testWidgets('renders tiny tier without labels or bearing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 60,
                height: 30,
                child: ReturnGlideWidget(
                  requiredGlide: 8.1,
                  distanceMeters: 5000,
                  tier: SizeTier.tiny,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('8.1'), findsOneWidget);
      expect(find.text('REQ L/D'), findsNothing);
      expect(find.text('RTL'), findsNothing);
    });

    testWidgets('renders stale state indicator when isStale is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 280,
                height: 160,
                child: ReturnGlideWidget(
                  requiredGlide: 5.5,
                  distanceMeters: 2000,
                  altitudeMarginMeters: 250,
                  isStale: true,
                  tier: SizeTier.regular,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('STALE'), findsOneWidget);
    });
  });
}
