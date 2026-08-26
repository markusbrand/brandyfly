import 'package:brandyfly/services/igc_parser_service.dart';
import 'package:brandyfly/services/telemetry/igc_replay_telemetry_source.dart';
import 'package:brandyfly/services/telemetry/telemetry_types.dart';
import 'package:flutter_test/flutter_test.dart';

const sampleIgcContent = '''AXFH000
HFDTE150826
HFPLTPILOT:Markus Brandstätter
HFGTYGLIDERTYPE:Ozone Delta 5
HFDTM100GPSDATUM:WGS84
HFSITSITE:Krippenstein,AT
I043638FXA3941VXA4244GSP4547HDT
B1023034731478N01341504EA0209802098004003004306155
B1023044731478N01341504EA0209802098004003004306167
B1023054731479N01341503EA0209802098004003000306149
B1023064731479N01341503EA0209802098004003000306185
G00000000000000000000000000000000
''';

void main() {
  group('IGC Replay Telemetry Source Tests', () {
    test('Paces records with speed multiplier cycling and scrub navigation', () async {
      final parser = const IGCParserService();
      final flight = parser.parseIgc(sampleIgcContent);

      final replayer = IgcReplayTelemetrySource(
        flight: flight,
        initialSpeedMultiplier: 1,
      );

      expect(replayer.sourceType, TelemetrySourceType.igcReplay);
      expect(replayer.totalPoints, 4);
      expect(replayer.currentIndex, 0);

      final snapshots = <TelemetrySnapshot>[];
      final sub = replayer.telemetryStream.listen(snapshots.add);

      await replayer.start();
      expect(replayer.isRunning, isTrue);

      // Verify speed multiplier cycling 1x -> 2x -> 5x -> 10x -> 1x
      expect(replayer.speedMultiplier, 1);
      replayer.cycleSpeedMultiplier();
      expect(replayer.speedMultiplier, 2);
      replayer.cycleSpeedMultiplier();
      expect(replayer.speedMultiplier, 5);
      replayer.cycleSpeedMultiplier();
      expect(replayer.speedMultiplier, 10);
      replayer.cycleSpeedMultiplier();
      expect(replayer.speedMultiplier, 1);

      // Verify scrub navigation
      replayer.seekTo(2);
      expect(replayer.currentIndex, 2);

      replayer.seekToRatio(0.5);
      expect(replayer.currentIndex, closeTo(flight.points.length / 2, 1));

      // Step synchronously
      final prevIndex = replayer.currentIndex;
      replayer.stepSynchronously();
      expect(replayer.currentIndex, prevIndex + 1);

      await replayer.pause();
      expect(replayer.isPaused, isTrue);

      await replayer.stop();
      expect(replayer.currentIndex, 0);

      await sub.cancel();
      replayer.dispose();
    });

    test('Malformed IGC records and corrupted lines are handled gracefully without exceptions', () {
      const corruptedIgc = '''
AXFH001
HFDTE150826
B1200004731450N01341500EA0150001505
BINVALIDRECORDCORRUPTED
B120001
B1200024731460N01341520EV0150201508
B9999999999999N999999999E9999999999
B1200044731480N01341540EA0151001515
G00000000000000000000000000000000
''';

      final parser = const IGCParserService();
      final flight = parser.parseIgc(corruptedIgc);

      // Should parse valid lines and skip corrupted ones cleanly
      expect(flight.points, isNotEmpty);
      expect(flight.points.length, greaterThanOrEqualTo(2));

      // Feed corrupted flight into IgcReplayTelemetrySource
      final source = IgcReplayTelemetrySource(flight: flight);
      expect(() => source.stepSynchronously(), returnsNormally);
      source.dispose();
    });
  });
}
