import 'package:brandyfly/domain/models/cockpit_telemetry.dart';
import 'package:brandyfly/models/lat_lng.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CockpitTelemetry flight timing & RTL', () {
    test('defaults to null flight timing and RTL values', () {
      const t = CockpitTelemetry();
      expect(t.takeoffTime, isNull);
      expect(t.flightDuration, isNull);
      expect(t.takeoffLocation, isNull);
      expect(t.takeoffAltitude, isNull);
      expect(t.rtlDistanceMeters, isNull);
      expect(t.rtlBearingDegrees, isNull);
      expect(t.rtlRequiredGlide, isNull);
      expect(t.rtlAltitudeMarginMeters, isNull);
    });

    test('constructor retains flight timing and RTL navigation properties', () {
      final takeoff = DateTime(2026, 6, 15, 12, 30, 0);
      const duration = Duration(minutes: 45, seconds: 12);
      const launchLoc = LatLng(47.5, 13.6);

      final t = CockpitTelemetry(
        takeoffTime: takeoff,
        flightDuration: duration,
        takeoffLocation: launchLoc,
        takeoffAltitude: 1200.0,
        rtlDistanceMeters: 4500.0,
        rtlBearingDegrees: 185.0,
        rtlRequiredGlide: 7.2,
        rtlAltitudeMarginMeters: 625.0,
      );

      expect(t.takeoffTime, takeoff);
      expect(t.flightDuration, duration);
      expect(t.takeoffLocation, launchLoc);
      expect(t.takeoffAltitude, 1200.0);
      expect(t.rtlDistanceMeters, 4500.0);
      expect(t.rtlBearingDegrees, 185.0);
      expect(t.rtlRequiredGlide, 7.2);
      expect(t.rtlAltitudeMarginMeters, 625.0);
    });

    test('fromMap parses flight timing and RTL fields', () {
      final t = CockpitTelemetry.fromMap({
        'takeoffTime': '2026-06-15T12:30:00.000Z',
        'flightDuration': 3600,
        'takeoffLocation': {'latitude': 47.5, 'longitude': 13.6},
        'takeoffAltitude': 1100,
        'rtlDistanceMeters': 3200,
        'rtlBearingDegrees': 90,
        'rtlRequiredGlide': 5.5,
        'rtlAltitudeMarginMeters': 580,
      });

      expect(t.takeoffTime, DateTime.parse('2026-06-15T12:30:00.000Z'));
      expect(t.flightDuration, const Duration(seconds: 3600));
      expect(t.takeoffLocation, const LatLng(47.5, 13.6));
      expect(t.takeoffAltitude, 1100.0);
      expect(t.rtlDistanceMeters, 3200.0);
      expect(t.rtlBearingDegrees, 90.0);
      expect(t.rtlRequiredGlide, 5.5);
      expect(t.rtlAltitudeMarginMeters, 580.0);
    });

    test('copyWith updates and clears flight timing and RTL fields', () {
      final takeoff = DateTime(2026, 6, 15, 12, 30, 0);
      final initial = CockpitTelemetry(
        takeoffTime: takeoff,
        flightDuration: const Duration(minutes: 10),
        rtlDistanceMeters: 1000.0,
      );

      final updated = initial.copyWith(
        flightDuration: const Duration(minutes: 15),
        rtlDistanceMeters: 1500.0,
        rtlRequiredGlide: 6.0,
      );

      expect(updated.takeoffTime, takeoff);
      expect(updated.flightDuration, const Duration(minutes: 15));
      expect(updated.rtlDistanceMeters, 1500.0);
      expect(updated.rtlRequiredGlide, 6.0);

      final cleared = updated.copyWith(
        takeoffTime: null,
        flightDuration: null,
        rtlRequiredGlide: null,
      );
      expect(cleared.takeoffTime, isNull);
      expect(cleared.flightDuration, isNull);
      expect(cleared.rtlRequiredGlide, isNull);
      expect(cleared.rtlDistanceMeters, 1500.0);
    });
  });
}
