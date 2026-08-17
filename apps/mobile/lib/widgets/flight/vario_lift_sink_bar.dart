import 'package:flutter/material.dart';
import '../../models/ui_config.dart';

class VarioLiftSinkBar extends StatelessWidget {
  const VarioLiftSinkBar({
    super.key,
    required this.climbRateMs,
    required this.style,
  });

  final double climbRateMs;
  final LiftSinkBarStyle style;

  @override
  Widget build(BuildContext context) {
    switch (style) {
      case LiftSinkBarStyle.analogDial:
        return _buildAnalogDial(context);
      case LiftSinkBarStyle.screenEdgeGlow:
        return _buildScreenEdgeGlow(context);
      case LiftSinkBarStyle.verticalEdgeBar:
      default:
        return _buildVerticalEdgeBar(context);
    }
  }

  // Option 1: Vertical Edge Bar
  Widget _buildVerticalEdgeBar(BuildContext context) {
    final isLift = climbRateMs >= 0;
    final absVal = climbRateMs.abs().clamp(0.0, 5.0);
    final fillPercent = absVal / 5.0;

    return Container(
      width: 48,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          Text(
            isLift ? '+${climbRateMs.toStringAsFixed(1)}' : climbRateMs.toStringAsFixed(1),
            style: TextStyle(
              color: isLift ? Colors.greenAccent : Colors.redAccent,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 16,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                FractionallySizedBox(
                  heightFactor: fillPercent,
                  child: Container(
                    width: 16,
                    decoration: BoxDecoration(
                      color: isLift ? Colors.greenAccent : Colors.redAccent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'm/s',
            style: TextStyle(color: Colors.white54, fontSize: 10),
          ),
        ],
      ),
    );
  }

  // Option 2: Analog Dial
  Widget _buildAnalogDial(BuildContext context) {
    final isLift = climbRateMs >= 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade900,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.cyanAccent.withAlpha(100)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'VARIO DIAL',
            style: TextStyle(color: Colors.cyanAccent, fontSize: 10),
          ),
          const SizedBox(height: 8),
          Icon(
            isLift ? Icons.speed_rounded : Icons.south_rounded,
            color: isLift ? Colors.greenAccent : Colors.redAccent,
            size: 32,
          ),
          const SizedBox(height: 4),
          Text(
            '${climbRateMs.toStringAsFixed(2)} m/s',
            style: TextStyle(
              color: isLift ? Colors.greenAccent : Colors.redAccent,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Option 3: Screen Edge Glow
  Widget _buildScreenEdgeGlow(BuildContext context) {
    final isLift = climbRateMs >= 0;
    final color = isLift ? Colors.greenAccent : Colors.redAccent;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(40),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 2),
        boxShadow: [
          BoxShadow(color: color.withAlpha(100), blurRadius: 16),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'VARIO GLOW',
            style: TextStyle(color: Colors.white70, fontSize: 10),
          ),
          const SizedBox(height: 4),
          Text(
            '${climbRateMs >= 0 ? '+' : ''}${climbRateMs.toStringAsFixed(1)} m/s',
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
