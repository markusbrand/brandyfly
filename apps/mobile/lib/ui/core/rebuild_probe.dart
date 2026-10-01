import 'package:flutter/foundation.dart';

/// Opt-in build counter used by rebuild-budget performance tests.
///
/// Disabled by default; when disabled [tick] is a single boolean check.
class RebuildProbe {
  RebuildProbe._();

  static bool enabled = false;
  static final Map<String, int> _counts = <String, int>{};

  static void tick(String key) {
    if (!enabled) return;
    _counts[key] = (_counts[key] ?? 0) + 1;
  }

  static int count(String key) => _counts[key] ?? 0;

  /// Sum of counts for keys starting with [prefix].
  static int countPrefix(String prefix) {
    var total = 0;
    _counts.forEach((k, v) {
      if (k.startsWith(prefix)) total += v;
    });
    return total;
  }

  @visibleForTesting
  static Map<String, int> get snapshot => Map.unmodifiable(_counts);

  static void reset() => _counts.clear();
}
