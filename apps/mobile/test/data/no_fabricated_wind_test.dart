import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the "honest wind" requirement: wind must never be derived from the
/// pilot heading or constant defaults anywhere in the app.
void main() {
  test('no wind is fabricated from heading or constants in lib/', () {
    final patterns = <RegExp>[
      RegExp(r'heading\s*\+\s*180(\.0)?\)\s*%\s*360'),
      RegExp(r"""['"]?wind(Dir|Speed|DirectionDeg|SpeedKmh)['"]?\s*:\s*\d"""),
    ];
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (patterns.any((p) => p.hasMatch(lines[i]))) {
          offenders.add('${f.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
