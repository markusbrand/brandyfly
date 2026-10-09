import 'dart:math' as math;

import 'package:brandyfly/domain/thermal_assistant/thermal_assistant_engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// One-hour, 10 Hz synthetic flight alternating glides and drifting thermals.
void main() {
  test(
    'thermal assistant: 1 h @ 10 Hz stays under 1 ms/sample and bounded',
    () {
      const hz = 10;
      const total = 3600 * hz;
      const rEarth = 6371000.0;
      final engine = ThermalAssistantEngine();
      var lat = 47.5;
      var lon = 13.7;
      var heading = 0.0;
      var maxCore = 0;
      var maxTrack = 0;
      var t = 1700000000000;

      final sw = Stopwatch()..start();
      for (var i = 0; i < total; i++) {
        // 4 min cycles: 90 s glide, 150 s circling.
        final phase = (i ~/ hz) % 240;
        final turn = phase < 90 ? 0.0 : 18.0;
        heading = (heading + turn / hz) % 360.0;
        final h = heading * math.pi / 180.0;
        final ve = 10.0 * math.sin(h) + 4.0;
        final vn = 10.0 * math.cos(h);
        lat += vn / hz / rEarth * 180.0 / math.pi;
        lon +=
            ve /
            hz /
            (rEarth * math.cos(lat * math.pi / 180.0)) *
            180.0 /
            math.pi;
        t += 1000 ~/ hz;
        engine.update(
          ThermalSample(
            timestampMs: t,
            position: GeoPosition(lat, lon),
            headingDeg: heading,
            climbRateMs: turn > 0 ? 2.0 + math.sin(i / 7.0) : -1.1,
          ),
        );
        maxCore = math.max(maxCore, engine.coreSampleCount);
        maxTrack = math.max(maxTrack, engine.trackSampleCount);
      }
      sw.stop();

      final meanUs = sw.elapsedMicroseconds / total;
      // ignore: avoid_print
      print(
        'thermal assistant mean ${meanUs.toStringAsFixed(1)} µs/sample, '
        'max core $maxCore, max track $maxTrack',
      );
      expect(meanUs, lessThan(1000.0));
      expect(maxCore, lessThanOrEqualTo(60 * hz + 1));
      expect(maxTrack, lessThanOrEqualTo(300 + 1));
      expect(engine.state.wind, isNotNull);
    },
  );
}
