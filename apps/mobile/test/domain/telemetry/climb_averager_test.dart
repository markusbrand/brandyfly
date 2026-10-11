import 'package:brandyfly/domain/thermal_assistant/climb_averager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ClimbAverager', () {
    test('returns 0.0 when empty', () {
      final averager = ClimbAverager();
      expect(averager.calculateAverage(), 0.0);
    });

    test('calculates correct average over window', () {
      final averager = ClimbAverager(
        defaultWindow: const Duration(seconds: 20),
      );

      // Feed 20 samples at 1-second intervals (0s to 19s)
      for (int i = 0; i < 20; i++) {
        averager.addSample(i * 1000, 2.0);
      }
      expect(averager.calculateAverage(), closeTo(2.0, 0.001));

      // Add a mix of 4.0 and 2.0
      // At t=20s to t=29s (10 samples of 4.0)
      for (int i = 20; i < 30; i++) {
        averager.addSample(i * 1000, 4.0);
      }
      // Over the last 20s (t=9s to t=29s): 11 samples of 2.0, 10 samples of 4.0 -> average = 62 / 21 = 2.952
      expect(averager.calculateAverage(), closeTo(62.0 / 21.0, 0.001));

      // Over a 10s window (t=19s to t=29s): 1 sample of 2.0 + 10 samples of 4.0 -> 42 / 11 = 3.818
      expect(
        averager.calculateAverage(const Duration(seconds: 10)),
        closeTo(42.0 / 11.0, 0.001),
      );
    });

    test('clears buffer on gap exceeding 5 seconds', () {
      final averager = ClimbAverager();

      averager.addSample(1000, 3.0);
      averager.addSample(2000, 3.0);
      expect(averager.calculateAverage(), 3.0);

      // Gap of 6000 ms (t=2000 to t=8000)
      averager.addSample(8000, 1.0);
      expect(averager.sampleCount, 1);
      expect(averager.calculateAverage(), 1.0);
    });

    test('reset clears all samples', () {
      final averager = ClimbAverager();
      averager.addSample(1000, 2.5);
      expect(averager.sampleCount, 1);

      averager.reset();
      expect(averager.sampleCount, 0);
      expect(averager.calculateAverage(), 0.0);
    });
  });
}
