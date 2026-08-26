import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('camera_script.json', () {
    late Map<String, dynamic> script;

    setUpAll(() async {
      final data = await rootBundle.loadString(
        'assets/benchmark_fixtures/camera_script.json',
      );
      script = jsonDecode(data) as Map<String, dynamic>;
    });

    test('parses without error', () {
      expect(script, isA<Map<String, dynamic>>());
    });

    test('has version field', () {
      expect(script['version'], isA<String>());
    });

    test('waypoints is a non-empty list', () {
      final waypoints = script['waypoints'];
      expect(waypoints, isA<List>());
      expect((waypoints as List).isNotEmpty, isTrue);
    });

    test('has at least 10 waypoints', () {
      final waypoints = script['waypoints'] as List;
      expect(waypoints.length, greaterThanOrEqualTo(10));
    });

    test('all waypoints have lat, lng, and zoom fields', () {
      final waypoints = (script['waypoints'] as List).cast<Map<String, dynamic>>();
      for (final wp in waypoints) {
        expect(wp.containsKey('lat'), isTrue, reason: 'missing lat in $wp');
        expect(wp.containsKey('lng'), isTrue, reason: 'missing lng in $wp');
        expect(wp.containsKey('zoom'), isTrue, reason: 'missing zoom in $wp');
      }
    });

    test('all waypoints are within Dachstein/Krippenstein bounding box', () {
      final waypoints = (script['waypoints'] as List).cast<Map<String, dynamic>>();
      for (final wp in waypoints) {
        final lat = (wp['lat'] as num).toDouble();
        final lng = (wp['lng'] as num).toDouble();
        expect(
          lat,
          inInclusiveRange(47.0, 48.0),
          reason: 'lat out of range in $wp',
        );
        expect(
          lng,
          inInclusiveRange(13.0, 14.5),
          reason: 'lng out of range in $wp',
        );
      }
    });

    test('zoom values are within maplibre supported range (1–22)', () {
      final waypoints = (script['waypoints'] as List).cast<Map<String, dynamic>>();
      for (final wp in waypoints) {
        final zoom = (wp['zoom'] as num).toDouble();
        expect(zoom, inInclusiveRange(1.0, 22.0), reason: 'zoom out of range in $wp');
      }
    });

    test('has intervalSeconds field', () {
      expect(script['intervalSeconds'], isA<num>());
    });

    test('totalDurationSeconds matches waypoints * intervalSeconds (approx)', () {
      final waypoints = script['waypoints'] as List;
      final interval = (script['intervalSeconds'] as num).toDouble();
      final declared = (script['totalDurationSeconds'] as num).toDouble();
      // The last waypoint t value should equal totalDurationSeconds
      final lastWp = (waypoints.last as Map<String, dynamic>);
      final lastT = (lastWp['t'] as num? ?? 0).toDouble();
      expect(
        lastT,
        closeTo(declared, interval * 2),
        reason: 'last waypoint t should be near totalDurationSeconds',
      );
    });
  });
}
