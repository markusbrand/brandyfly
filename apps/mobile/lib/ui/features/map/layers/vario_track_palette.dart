import 'package:flutter/painting.dart';

/// Vario color gradient of the flight track (lift green, sink red).
abstract final class VarioTrackPalette {
  /// Continuous piecewise color interpolation mapping vertical speed (m/s)
  /// to a lift/sink colour stop.
  static Color colorFor(double vario) {
    if (vario <= -3.0) return const Color(0xFF991B1B); // Deep Dark Red
    if (vario < -1.5) {
      final t = (vario - (-3.0)) / (-1.5 - (-3.0));
      return Color.lerp(const Color(0xFF991B1B), const Color(0xFFEF4444), t)!;
    }
    if (vario < -0.5) {
      final t = (vario - (-1.5)) / (-0.5 - (-1.5));
      return Color.lerp(const Color(0xFFEF4444), const Color(0xFFFCA5A5), t)!;
    }
    if (vario <= 0.5) {
      return const Color(0xFF94A3B8); // Neutral Slate Grey
    }
    if (vario < 1.5) {
      final t = (vario - 0.5) / (1.5 - 0.5);
      return Color.lerp(const Color(0xFF86EFAC), const Color(0xFF22C55E), t)!;
    }
    if (vario < 3.5) {
      final t = (vario - 1.5) / (3.5 - 1.5);
      return Color.lerp(const Color(0xFF22C55E), const Color(0xFF15803D), t)!;
    }
    return const Color(0xFF15803D); // Dark Emerald Green
  }

  /// Muted neutral color of the older track tail.
  static const Color tailColor = Color(0xFF94A3B8);

  /// `#rrggbb` of [colorFor] with vario quantized to 0.1 m/s, so consecutive
  /// segments with near-identical climb share a color (and a feature).
  static String hexFor(double vario) {
    final q = (vario * 10).roundToDouble() / 10;
    return toHex(colorFor(q));
  }

  static String toHex(Color c) {
    final argb = c.toARGB32();
    return '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  }
}
