import 'package:flutter/material.dart';

/// Cockpit design tokens: a glanceable, sunlight-readable instrument palette.
///
/// Night panel background, bezel control surfaces, glass-cyan for active and
/// selected state, lift green / sink red for climb, caution amber for stale
/// data, warnings and overlaps.
class CockpitTokens {
  const CockpitTokens._();

  static const Color nightPanel = Color(0xFF0B0F14);
  static const Color bezel = Color(0xFF1C232B);
  static const Color bezelEdge = Color(0xFF3A4652);
  static const Color glassCyan = Color(0xFF3FE0F0);
  static const Color liftGreen = Color(0xFF3DDC84);
  static const Color sinkRed = Color(0xFFFF4D5E);
  static const Color cautionAmber = Color(0xFFFFB020);
  static const Color ink = Color(0xFFE8EEF2);
  static const Color inkMuted = Color(0xFF9AA7B2);

  /// Bundled condensed face (SIL OFL 1.1) used for instrument digits/labels.
  static const String instrumentFont = 'BarlowSemiCondensed';

  /// Tabular figures keep digits from jittering as values change.
  static const List<FontFeature> tabularFigures = [
    FontFeature.tabularFigures(),
  ];

  static const TextStyle instrumentValue = TextStyle(
    fontFamily: instrumentFont,
    fontFeatures: tabularFigures,
    fontWeight: FontWeight.w700,
    color: ink,
    height: 1.0,
  );

  static const TextStyle instrumentLabel = TextStyle(
    fontFamily: instrumentFont,
    fontWeight: FontWeight.w500,
    color: inkMuted,
    letterSpacing: 0.8,
    height: 1.0,
  );

  /// Edit-mode transition duration (skipped when animations are disabled).
  static const Duration editTransition = Duration(milliseconds: 150);

  /// Returns [editTransition], or zero when the platform requests reduced
  /// motion.
  static Duration transitionFor(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false
      ? Duration.zero
      : editTransition;
}
