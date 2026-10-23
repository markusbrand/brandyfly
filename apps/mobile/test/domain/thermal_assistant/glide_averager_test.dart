import 'package:brandyfly/domain/thermal_assistant/glide_averager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GlideAverager', () {
    test('converges to accurate L/D during steady descending glide', () {
      final averager = GlideAverager();

      // 36 km/h (10 m/s) at -1.25 m/s sink -> L/D = 10 / 1.25 = 8.0
      for (var i = 0; i <= 15; i++) {
        averager.addSample(i * 1000, 36.0, -1.25);
      }

      expect(averager.calculateGlide(fallbackGlide: 8.4), closeTo(8.0, 0.01));
    });

    test('returns fallbackGlide when climbing with no prior descending samples', () {
      final averager = GlideAverager();

      for (var i = 0; i < 10; i++) {
        averager.addSample(i * 1000, 32.0, 1.8);
      }

      expect(averager.calculateGlide(fallbackGlide: 8.4), 8.4);
    });

    test('retains last valid descending glide ratio when transitioning into climb', () {
      final averager = GlideAverager();

      // Establish a 9.0 L/D glide: 32.4 km/h (9.0 m/s) at -1.0 m/s
      for (var i = 0; i <= 15; i++) {
        averager.addSample(i * 1000, 32.4, -1.0);
      }
      expect(averager.calculateGlide(fallbackGlide: 8.4), closeTo(9.0, 0.01));

      // Transition into strong climb (+2.5 m/s) for 15 seconds
      for (var i = 16; i <= 31; i++) {
        averager.addSample(i * 1000, 30.0, 2.5);
      }
      expect(averager.calculateGlide(fallbackGlide: 8.4), closeTo(9.0, 0.01));
    });

    test('clamps extreme glide ratios to [0.5, 50.0] and rejects stationary speeds', () {
      final averager = GlideAverager();

      // Stationary on ground (< 5 km/h) with barometric noise (-0.2 m/s)
      averager.addSample(1000, 2.0, -0.2);
      expect(averager.calculateGlide(fallbackGlide: 8.4), 8.4);

      // Extremely shallow sink: 54 km/h (15 m/s) at -0.1 m/s -> raw 150 -> clamped to 50.0
      averager.reset();
      averager.addSample(1000, 54.0, -0.1);
      expect(averager.calculateGlide(fallbackGlide: 8.4), 50.0);

      // Steep descent: 18 km/h (5 m/s) at -15 m/s -> raw 0.33 -> clamped to 0.5
      averager.reset();
      averager.addSample(1000, 18.0, -15.0);
      expect(averager.calculateGlide(fallbackGlide: 8.4), 0.5);
    });

    test('clears prior window samples when telemetry gap exceeds 5 seconds', () {
      final averager = GlideAverager();

      // Initial glide at L/D = 6.0 (36 km/h = 10 m/s, -1.6667 m/s)
      for (var i = 0; i < 5; i++) {
        averager.addSample(i * 1000, 36.0, -10.0 / 6.0);
      }
      expect(averager.sampleCount, 5);
      expect(averager.calculateGlide(), closeTo(6.0, 0.05));

      // 6-second gap (> 5000ms) followed by new glide at L/D = 10.0 (36 km/h = 10 m/s, -1.0 m/s)
      averager.addSample(11000, 36.0, -1.0);
      expect(averager.sampleCount, 1);
      expect(averager.calculateGlide(), closeTo(10.0, 0.01));
    });
  });
}
