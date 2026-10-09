// Cross-runtime parity: the Dart thermal assistant must reproduce the Rust
// reference output stored in packages/contracts/fixtures/thermal_assistant/.
// Regenerate fixtures with `cargo run -p flight_core --bin thermal_fixtures`.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:brandyfly/domain/thermal_assistant/thermal_assistant.dart';
import 'package:brandyfly/domain/thermal_assistant/thermal_types.dart';
import 'package:flutter_test/flutter_test.dart';

const double windSpeedToleranceKmh = 0.5;
const double windDirToleranceDeg = 2.0;
const double coreToleranceM = 2.0;
const List<String> requiredScenarios = [
  'no_wind_thermal',
  'drift_thermal_10ms',
  'straight_glide',
  'erratic_reversals',
  'telemetry_gap',
  'stale_samples',
];

Directory _fixtureDir() {
  var dir = Directory.current;
  for (var i = 0; i < 4; i++) {
    final candidate = Directory(
      '${dir.path}/packages/contracts/fixtures/thermal_assistant',
    );
    if (candidate.existsSync()) return candidate;
    dir = dir.parent;
  }
  throw StateError(
    'thermal_assistant fixtures not found from ${Directory.current.path}',
  );
}

double _angleDiff(double a, double b) {
  final d = (a - b).abs() % 360.0;
  return d > 180.0 ? 360.0 - d : d;
}

double _distanceM(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371000.0;
  final dLat = (lat2 - lat1) * math.pi / 180.0;
  final dLon =
      (lon2 - lon1) * math.pi / 180.0 * math.cos(lat1 * math.pi / 180.0);
  return math.sqrt(dLat * dLat + dLon * dLon) * r;
}

String _turnName(TurnDirection t) => t.name;

void main() {
  final dir = _fixtureDir();
  final files =
      dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  test('all required scenarios are present', () {
    final names = files
        .map((f) => f.uri.pathSegments.last.replaceAll('.json', ''))
        .toSet();
    expect(names, containsAll(requiredScenarios));
  });

  for (final file in files) {
    final name = file.uri.pathSegments.last;
    test('parity: $name', () {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(json['schemaVersion'], 1);
      final samples = (json['samples'] as List).cast<Map<String, dynamic>>();
      final ta = ThermalAssistant();

      for (var i = 0; i < samples.length; i++) {
        final s = samples[i];
        final out = ta.update(
          ThermalSample(
            timestampMs: (s['tMs'] as num).toInt(),
            position: GeoPosition(
              (s['lat'] as num).toDouble(),
              (s['lon'] as num).toDouble(),
            ),
            headingDeg: (s['headingDeg'] as num).toDouble(),
            climbRateMs: (s['climbMs'] as num).toDouble(),
            stale: s['stale'] as bool,
          ),
        );
        final exp = s['expected'] as Map<String, dynamic>;
        final where = '$name sample $i (tMs=${s['tMs']})';

        expect(out.state.mode.name, exp['mode'], reason: '$where mode');
        expect(_turnName(out.state.turn), exp['turn'], reason: '$where turn');

        final ew = exp['wind'] as Map<String, dynamic>?;
        if (ew == null) {
          expect(out.wind, isNull, reason: '$where wind');
        } else {
          expect(out.wind, isNotNull, reason: '$where wind');
          expect(
            out.wind!.speedKmh,
            closeTo((ew['speedKmh'] as num).toDouble(), windSpeedToleranceKmh),
            reason: '$where wind speed',
          );
          expect(
            _angleDiff(
              out.wind!.directionDeg,
              (ew['dirDeg'] as num).toDouble(),
            ),
            lessThanOrEqualTo(windDirToleranceDeg),
            reason: '$where wind dir',
          );
          expect(
            out.windUpdatedMs,
            (ew['updatedMs'] as num).toInt(),
            reason: '$where wind updated',
          );
        }

        final ec = exp['core'] as Map<String, dynamic>?;
        if (ec == null) {
          expect(out.core, isNull, reason: '$where core');
        } else {
          expect(out.core, isNotNull, reason: '$where core');
          final d = _distanceM(
            out.core!.center.lat,
            out.core!.center.lon,
            (ec['lat'] as num).toDouble(),
            (ec['lon'] as num).toDouble(),
          );
          expect(
            d,
            lessThanOrEqualTo(coreToleranceM),
            reason: '$where core distance',
          );
        }
      }
    });
  }
}
