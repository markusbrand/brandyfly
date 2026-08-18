import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/ui_config.dart';

class WindDirectionWidget extends StatelessWidget {
  const WindDirectionWidget({
    super.key,
    required this.directionDegrees,
    required this.speedKmH,
    required this.style,
  });

  final double directionDegrees;
  final double speedKmH;
  final WindWidgetStyle style;

  @override
  Widget build(BuildContext context) {
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Transform.rotate(
            angle: directionDegrees * (math.pi / 180),
            child: const Icon(
              Icons.navigation,
              color: Colors.lightBlueAccent,
              size: 36,
            ),
          ),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'WIND',
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  Text(
                    '${speedKmH.toStringAsFixed(1)} km/h',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${directionDegrees.toInt()}°',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Option 2: Mini Compass Rose
  Widget _buildMiniCompassRose(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white30, width: 1.5),
            ),
            child: const Center(
              child: Text(
                'N',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ),
          Transform.rotate(
            angle: directionDegrees * (math.pi / 180),
            child: const Icon(
              Icons.arrow_upward_rounded,
              color: Colors.amberAccent,
              size: 32,
            ),
          ),
          Positioned(
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              color: Colors.black87,
              child: Text(
                '${speedKmH.toInt()} km/h',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Option 3: Windsock Indicator
  Widget _buildWindsockIndicator(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade900.withAlpha(180),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orangeAccent),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.air, color: Colors.orangeAccent, size: 28),
          const SizedBox(width: 8),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
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
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
