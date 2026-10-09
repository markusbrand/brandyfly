import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../domain/models/size_tier.dart';
import '../../../../domain/models/ui_config.dart';

class WindDirectionWidget extends StatelessWidget {
  const WindDirectionWidget({
    super.key,
    required double? directionDegrees,
    required double? speedKmH,
    required this.style,
    this.tier,
    this.isStale = false,
  }) : _direction = directionDegrees,
       _speed = speedKmH;

  final double? _direction;
  final double? _speed;
  final WindWidgetStyle style;

  /// Wind estimate older than the staleness limit; rendered greyed with a
  /// STALE badge.
  final bool isStale;

  /// Whether a wind estimate is available. Wind is never fabricated: without
  /// an estimate an explicit "no estimate" state is shown.
  bool get hasEstimate => _direction != null && _speed != null;

  double get directionDegrees => _direction ?? 0.0;
  double get speedKmH => _speed ?? 0.0;

  /// Content tier; tiny renders the direction arrow only. Null keeps the full
  /// layout.
  final SizeTier? tier;

  @override
  Widget build(BuildContext context) {
    if (!hasEstimate) {
      return Semantics(
        label: 'Wind: no estimate',
        readOnly: true,
        child: _buildNoEstimate(),
      );
    }
    final styled = _buildStyledWind(context);
    return Semantics(
      label:
          'Wind: ${speedKmH.toStringAsFixed(1)} km/h at ${directionDegrees.toInt()} degrees${isStale ? ', stale' : ''}',
      readOnly: true,
      child: isStale ? _buildStale(styled) : styled,
    );
  }

  /// Explicit absence of a wind estimate (all styles).
  Widget _buildNoEstimate() {
    final tiny = tier == SizeTier.tiny;
    return SizedBox.expand(
      key: const Key('wind_no_estimate'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(160),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white12, width: 1),
        ),
        child: FittedBox(
          fit: BoxFit.contain,
          child: tiny
              ? const Text(
                  '--',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                )
              : const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'WIND',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '-- km/h',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                      ),
                    ),
                    Text(
                      'NO ESTIMATE',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  /// Greys out a stale estimate and adds a STALE badge.
  Widget _buildStale(Widget child) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            0.2126, 0.7152, 0.0722, 0, 0, //
            0.2126, 0.7152, 0.0722, 0, 0, //
            0.2126, 0.7152, 0.0722, 0, 0, //
            0, 0, 0, 0.6, 0, //
          ]),
          child: child,
        ),
        Positioned(
          top: 1,
          right: 1,
          child: Container(
            key: const Key('wind_stale_badge'),
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.amber.shade800,
              borderRadius: BorderRadius.circular(3),
            ),
            child: const Text(
              'STALE',
              style: TextStyle(
                color: Colors.black,
                fontSize: 8,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStyledWind(BuildContext context) {
    if (tier == SizeTier.tiny) {
      return SizedBox.expand(
        child: Container(
          padding: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(160),
            borderRadius: BorderRadius.circular(4),
          ),
          child: FittedBox(
            fit: BoxFit.contain,
            child: Transform.rotate(
              angle: directionDegrees * (math.pi / 180),
              child: const Icon(
                Icons.navigation,
                color: Colors.lightBlueAccent,
                size: 36,
              ),
            ),
          ),
        ),
      );
    }
    switch (style) {
      case WindWidgetStyle.relativeArrow:
        return _buildRelativeArrow(context);
      case WindWidgetStyle.miniCompassRose:
        return _buildMiniCompassRose(context);
      case WindWidgetStyle.windsockIndicator:
        return _buildWindsockIndicator(context);
    }
  }

  // Option 1: Relative Arrow
  Widget _buildRelativeArrow(BuildContext context) {
    return SizedBox.expand(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(160),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.rotate(
                angle: directionDegrees * (math.pi / 180),
                child: const Icon(
                  Icons.navigation,
                  color: Colors.lightBlueAccent,
                  size: 36,
                ),
              ),
              const SizedBox(width: 6),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'WIND',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${speedKmH.toStringAsFixed(1)} km/h',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                    ),
                  ),
                  Text(
                    '${directionDegrees.toInt()}°',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Option 2: Mini Compass Rose
  Widget _buildMiniCompassRose(BuildContext context) {
    return SizedBox.expand(
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.blueGrey.shade900,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: 80,
              height: 80,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white38, width: 1.5),
                    ),
                    child: const Center(
                      child: Text(
                        'N',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  Transform.rotate(
                    angle: directionDegrees * (math.pi / 180),
                    child: const Icon(
                      Icons.arrow_upward_rounded,
                      color: Colors.amberAccent,
                      size: 38,
                    ),
                  ),
                  Positioned(
                    bottom: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        '${speedKmH.toInt()} km/h',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Option 3: Windsock Indicator
  Widget _buildWindsockIndicator(BuildContext context) {
    return SizedBox.expand(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.orange.shade900.withAlpha(200),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orangeAccent, width: 1.2),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.contain,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.air, color: Colors.orangeAccent, size: 32),
                const SizedBox(width: 6),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'WINDSOCK',
                      style: TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${speedKmH.toStringAsFixed(0)} km/h @ ${directionDegrees.toInt()}°',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
