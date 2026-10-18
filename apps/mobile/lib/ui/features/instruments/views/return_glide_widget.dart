import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../domain/models/size_tier.dart';
import '../../../core/theme/cockpit_tokens.dart';

/// Cockpit instrument widget displaying return-to-launch (RTL) navigation
/// metrics: required glide ratio (L/D), distance to launch, altitude margin
/// above launch, and bearing indicator back to launch.
class ReturnGlideWidget extends StatelessWidget {
  const ReturnGlideWidget({
    super.key,
    this.requiredGlide,
    this.distanceMeters,
    this.altitudeMarginMeters,
    this.bearingDegrees,
    this.gliderHeadingDegrees,
    this.isStale = false,
    this.tier,
  });

  /// Required glide ratio to reach launch elevation. Null when below launch
  /// or when in standby.
  final double? requiredGlide;

  /// Horizontal geodesic distance to launch in meters.
  final double? distanceMeters;

  /// Vertical altitude delta relative to launch elevation in meters.
  /// Positive when above launch, negative when below launch.
  final double? altitudeMarginMeters;

  /// True bearing from current aircraft position towards launch in degrees [0, 360).
  final double? bearingDegrees;

  /// Current glider heading/track in degrees [0, 360), used to render a relative
  /// navigation arrow. If null, the arrow points relative to true north.
  final double? gliderHeadingDegrees;

  /// True when incoming telemetry packets are delayed or missing.
  final bool isStale;

  /// Target size tier. When null, tier is derived from layout constraints.
  final SizeTier? tier;

  bool get isStandby => distanceMeters == null;
  bool get isBelowLaunch =>
      altitudeMarginMeters != null && altitudeMarginMeters! < 0;

  static String formatGlide(double? glide, {bool isBelowLaunch = false}) {
    if (glide == null || isBelowLaunch) return '---';
    return glide.toStringAsFixed(1);
  }

  static String formatDistance(double? meters) {
    if (meters == null) return '---';
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  static String formatAltitudeMargin(double? margin) {
    if (margin == null) return '---';
    final rounded = margin.round();
    if (rounded >= 0) {
      return '+$rounded m';
    }
    return '$rounded m';
  }

  static String formatBearing(double? bearing) {
    if (bearing == null) return '---';
    final b = ((bearing.round() % 360) + 360) % 360;
    return '$b°';
  }

  @override
  Widget build(BuildContext context) {
    final glideStr = formatGlide(requiredGlide, isBelowLaunch: isBelowLaunch);
    final distStr = formatDistance(distanceMeters);
    final marginStr = formatAltitudeMargin(altitudeMarginMeters);

    final semantic = isStandby
        ? 'Return to launch: standby'
        : 'Return to launch: glide $glideStr, distance $distStr, margin $marginStr${isBelowLaunch ? ', below launch' : ''}${isStale ? ', data stale' : ''}';

    return Semantics(
      label: semantic,
      readOnly: true,
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxHeight < 6 || constraints.maxWidth < 6) {
            return const SizedBox.shrink();
          }
          final effectiveTier =
              tier ?? sizeTierFor(constraints.maxWidth, constraints.maxHeight);

          Color borderColor = Colors.white24;
          if (isStale) {
            borderColor = CockpitTokens.cautionAmber.withAlpha(180);
          } else if (isBelowLaunch) {
            borderColor = CockpitTokens.sinkRed.withAlpha(180);
          }

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(160),
              borderRadius: BorderRadius.circular(6.0),
              border: Border.all(color: borderColor, width: 1.0),
            ),
            child: _buildContent(
              context,
              effectiveTier,
              glideStr,
              distStr,
              marginStr,
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    SizeTier effectiveTier,
    String glideStr,
    String distStr,
    String marginStr,
  ) {
    if (effectiveTier == SizeTier.tiny) {
      return _buildTiny(glideStr);
    }
    if (effectiveTier == SizeTier.compact) {
      return _buildCompact(glideStr, distStr, marginStr);
    }
    return _buildRegular(context, glideStr, distStr, marginStr);
  }

  Widget _buildTiny(String glideStr) {
    return Center(
      child: FittedBox(
        fit: BoxFit.contain,
        child: Text(
          glideStr,
          style: CockpitTokens.instrumentValue.copyWith(
            color: isStale
                ? CockpitTokens.cautionAmber
                : (isBelowLaunch
                    ? CockpitTokens.sinkRed
                    : (isStandby
                        ? CockpitTokens.inkMuted
                        : CockpitTokens.ink)),
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildCompact(
    String glideStr,
    String distStr,
    String marginStr,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'RTL',
                style: CockpitTokens.instrumentLabel.copyWith(
                  fontSize: 10,
                  letterSpacing: 0.6,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isStale)
              _buildBadge('STALE', CockpitTokens.cautionAmber)
            else if (isBelowLaunch)
              _buildBadge('BELOW', CockpitTokens.sinkRed)
            else if (isStandby)
              _buildBadge('STANDBY', Colors.white70)
            else
              Text(
                distStr,
                style: CockpitTokens.instrumentLabel.copyWith(
                  fontSize: 9,
                  color: Colors.white70,
                ),
              ),
          ],
        ),
        Expanded(
          child: Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    glideStr,
                    style: CockpitTokens.instrumentValue.copyWith(
                      color: isStale
                          ? CockpitTokens.cautionAmber
                          : (isBelowLaunch
                              ? CockpitTokens.sinkRed
                              : (isStandby
                                  ? CockpitTokens.inkMuted
                                  : CockpitTokens.ink)),
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'L/D',
                    style: CockpitTokens.instrumentLabel.copyWith(
                      fontSize: 10,
                      color: CockpitTokens.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegular(
    BuildContext context,
    String glideStr,
    String distStr,
    String marginStr,
  ) {
    final bearingStr = formatBearing(bearingDegrees);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'RETURN TO LAUNCH',
                  style: CockpitTokens.instrumentLabel.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            if (isStale)
              _buildBadge('STALE', CockpitTokens.cautionAmber)
            else if (isBelowLaunch)
              _buildBadge('BELOW LAUNCH', CockpitTokens.sinkRed)
            else if (isStandby)
              _buildBadge('STANDBY', Colors.white70)
            else
              _buildBadge('AIRBORNE', CockpitTokens.liftGreen),
          ],
        ),
        Expanded(
          child: Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    glideStr,
                    style: CockpitTokens.instrumentValue.copyWith(
                      color: isStale
                          ? CockpitTokens.cautionAmber
                          : (isBelowLaunch
                              ? CockpitTokens.sinkRed
                              : (isStandby
                                  ? CockpitTokens.inkMuted
                                  : CockpitTokens.ink)),
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'REQ L/D',
                    style: CockpitTokens.instrumentLabel.copyWith(
                      fontSize: 12,
                      color: CockpitTokens.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'DIST $distStr',
                  style: CockpitTokens.instrumentLabel.copyWith(
                    fontSize: 10,
                    color: Colors.white70,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Text(
                  'ALT $marginStr',
                  style: CockpitTokens.instrumentLabel.copyWith(
                    fontSize: 10,
                    color: isBelowLaunch
                        ? CockpitTokens.sinkRed
                        : (altitudeMarginMeters != null
                            ? CockpitTokens.liftGreen
                            : Colors.white70),
                    fontWeight: isBelowLaunch ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildBearingArrow(),
                    const SizedBox(width: 2),
                    Text(
                      bearingStr,
                      style: CockpitTokens.instrumentLabel.copyWith(
                        fontSize: 10,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBearingArrow() {
    if (bearingDegrees == null) {
      return const SizedBox.shrink();
    }
    // Relative angle pointing towards launch
    final relDegrees = gliderHeadingDegrees != null
        ? (bearingDegrees! - gliderHeadingDegrees!)
        : bearingDegrees!;
    final rad = relDegrees * math.pi / 180.0;

    return Transform.rotate(
      angle: rad,
      child: const Icon(
        Icons.navigation,
        size: 11,
        color: CockpitTokens.glassCyan,
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withAlpha(40),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: color.withAlpha(160),
          width: 0.8,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
