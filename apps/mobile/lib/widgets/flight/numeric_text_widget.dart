import 'package:flutter/material.dart';
import '../../models/ui_config.dart';

class NumericTextWidget extends StatelessWidget {
  const NumericTextWidget({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.style,
  });

  final String label;
  final String value;
  final String unit;
  final NumericWidgetStyle style;

  @override
  Widget build(BuildContext context) {
    switch (style) {
      case NumericWidgetStyle.highContrastBox:
        return _buildHighContrastBox(context);
      case NumericWidgetStyle.circularGauge:
        return _buildCircularGauge(context);
      case NumericWidgetStyle.retroDigital:
        return _buildRetroDigital(context);
      case NumericWidgetStyle.minimalistText:
      default:
        return _buildMinimalistText(context);
    }
  }

  // Option 1: Minimalist Text
  Widget _buildMinimalistText(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Option 2: High-Contrast Box
  Widget _buildHighContrastBox(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.yellow.shade400,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black, width: 3),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: Colors.black,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$value $unit',
            style: const TextStyle(
              color: Colors.black,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  // Option 3: Circular Gauge
  Widget _buildCircularGauge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade900,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.cyanAccent, width: 2),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: Colors.cyanAccent,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              unit,
              style: const TextStyle(color: Colors.white54, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  // Option 4: Retro Digital
  Widget _buildRetroDigital(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.greenAccent.shade400, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: Colors.greenAccent.shade200,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$value $unit',
            style: TextStyle(
              color: Colors.greenAccent.shade400,
              fontSize: 26,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              shadows: const [
                Shadow(color: Colors.greenAccent, blurRadius: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
