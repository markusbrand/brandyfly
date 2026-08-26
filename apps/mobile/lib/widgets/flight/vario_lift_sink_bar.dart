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
      case LiftSinkBarStyle.verticalEdgeBar:
        return _buildVerticalEdgeBar(context);
      case LiftSinkBarStyle.analogDial:
        return _buildAnalogDial(context);
      case LiftSinkBarStyle.screenEdgeGlow:
        return _buildScreenEdgeGlow(context);
    }
  }

  // Option 1: Vertical Edge Bar
  Widget _buildVerticalEdgeBar(BuildContext context) {
    final isLift = climbRateMs >= 0;
    final absVal = climbRateMs.abs().clamp(0.0, 5.0);
    final fillPercent = absVal / 5.0;

    return SizedBox.expand(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white24),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: 50,
              height: 120,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isLift
                        ? '+${climbRateMs.toStringAsFixed(1)}'
                        : climbRateMs.toStringAsFixed(1),
                    style: TextStyle(
                      color: isLift ? Colors.greenAccent : Colors.redAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Container(
                      width: 16,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade900,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Align(
                        alignment: isLift ? Alignment.bottomCenter : Alignment.topCenter,
                        child: FractionallySizedBox(
                          heightFactor: fillPercent,
                          child: Container(
                            width: 16,
                            decoration: BoxDecoration(
                              color: isLift ? Colors.greenAccent : Colors.redAccent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'm/s',
                    style: TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Option 2: Analog Dial
  Widget _buildAnalogDial(BuildContext context) {
    final isLift = climbRateMs >= 0;
    return SizedBox.expand(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blueGrey.shade900,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.cyanAccent.withAlpha(100)),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.contain,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'VARIO DIAL',
                  style: TextStyle(color: Colors.cyanAccent, fontSize: 10),
                ),
                const SizedBox(height: 6),
                Icon(
                  isLift ? Icons.speed_rounded : Icons.south_rounded,
                  color: isLift ? Colors.greenAccent : Colors.redAccent,
                  size: 30,
                ),
                const SizedBox(height: 4),
                Text(
                  '${climbRateMs.toStringAsFixed(2)} m/s',
                  style: TextStyle(
                    color: isLift ? Colors.greenAccent : Colors.redAccent,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Option 3: Screen Edge Glow
  Widget _buildScreenEdgeGlow(BuildContext context) {
    final isLift = climbRateMs >= 0;
    final color = isLift ? Colors.greenAccent : Colors.redAccent;
    return SizedBox.expand(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withAlpha(40),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color, width: 2),
          boxShadow: [BoxShadow(color: color.withAlpha(100), blurRadius: 16)],
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.contain,
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
          ),
        ),
      ),
    );
  }
}
