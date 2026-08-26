import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('overlays.json', () {
    late Map<String, dynamic> overlays;

    setUpAll(() async {
      final data = await rootBundle.loadString(
        'assets/benchmark_fixtures/overlays.json',
      );
      overlays = jsonDecode(data) as Map<String, dynamic>;
    });

    test('parses without error', () {
      expect(overlays, isA<Map<String, dynamic>>());
    });

    test('airspacePolygons is a non-empty list', () {
      final airspaces = overlays['airspacePolygons'];
      expect(airspaces, isA<List>());
      expect((airspaces as List).isNotEmpty, isTrue);
    });

    test('has at least 2 airspace polygons', () {
      final airspaces = overlays['airspacePolygons'] as List;
      expect(airspaces.length, greaterThanOrEqualTo(2));
    });

    test('each airspace has id, label, and points', () {
      final airspaces =
          (overlays['airspacePolygons'] as List).cast<Map<String, dynamic>>();
      for (final as_ in airspaces) {
        expect(as_.containsKey('id'), isTrue);
        expect(as_.containsKey('label'), isTrue);
        expect(as_['points'], isA<List>());
        expect((as_['points'] as List).isNotEmpty, isTrue);
      }
    });

    test('flightTrack has points list', () {
      final track = overlays['flightTrack'] as Map<String, dynamic>;
      expect(track['points'], isA<List>());
      expect((track['points'] as List).isNotEmpty, isTrue);
    });

    test('thermalMarkers is a non-empty list', () {
      final thermals = overlays['thermalMarkers'];
      expect(thermals, isA<List>());
      expect((thermals as List).isNotEmpty, isTrue);
    });

    test('has at least 4 thermal markers', () {
      final thermals = overlays['thermalMarkers'] as List;
      expect(thermals.length, greaterThanOrEqualTo(4));
    });

    test('each thermal marker has id, lat, lng, strengthMs', () {
      final thermals =
          (overlays['thermalMarkers'] as List).cast<Map<String, dynamic>>();
      for (final t in thermals) {
        expect(t.containsKey('id'), isTrue);
        expect(t.containsKey('lat'), isTrue);
        expect(t.containsKey('lng'), isTrue);
        expect(t.containsKey('strengthMs'), isTrue);
      }
    });

    test('pilotPosition is present with lat, lng, headingDeg', () {
      final pilot = overlays['pilotPosition'] as Map<String, dynamic>;
      expect(pilot.containsKey('lat'), isTrue);
      expect(pilot.containsKey('lng'), isTrue);
      expect(pilot.containsKey('headingDeg'), isTrue);
    });

    test('peakMarkers is a non-empty list', () {
      final peaks = overlays['peakMarkers'];
      expect(peaks, isA<List>());
      expect((peaks as List).isNotEmpty, isTrue);
    });
  });
}
