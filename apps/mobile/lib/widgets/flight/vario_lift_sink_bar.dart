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
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 3),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(160),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Text(
                isLift
                    ? '+${climbRateMs.toStringAsFixed(1)}'
                    : climbRateMs.toStringAsFixed(1),
                style: TextStyle(
                  color: isLift ? Colors.greenAccent : Colors.redAccent,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 2),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: LayoutBuilder(
                  builder: (ctx, constraints) {
                    final halfH = constraints.maxHeight / 2;
                    return Stack(
                      children: [
                        // Center zero-line
                        Positioned(
                          left: 0,
                          right: 0,
                          top: halfH - 1,
                          height: 2,
                          child: Container(color: Colors.white38),
                        ),
                        // Lift bar (from center going up)
                        if (isLift)
                          Positioned(
                            left: 2,
                            right: 2,
                            bottom: halfH,
                            height: (halfH * fillPercent).clamp(0.0, halfH),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.greenAccent,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          )
                        // Sink bar (from center going down)
                        else
                          Positioned(
                            left: 2,
                            right: 2,
                            top: halfH,
                            height: (halfH * fillPercent).clamp(0.0, halfH),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'm/s',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, fontSize: 9, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // Option 2: Analog Dial
  Widget _buildAnalogDial(BuildContext context) {
    final isLift = climbRateMs >= 0;
    return SizedBox.expand(
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.blueGrey.shade900,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.cyanAccent.withAlpha(100), width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'VARIO DIAL',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.cyanAccent, fontSize: 9, fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: FittedBox(
                fit: BoxFit.contain,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isLift ? Icons.speed_rounded : Icons.south_rounded,
                      color: isLift ? Colors.greenAccent : Colors.redAccent,
                      size: 32,
                    ),
                    Text(
                      '${climbRateMs.toStringAsFixed(2)} m/s',
                      style: TextStyle(
                        color: isLift ? Colors.greenAccent : Colors.redAccent,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: color.withAlpha(35),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color, width: 1.5),
          boxShadow: [BoxShadow(color: color.withAlpha(80), blurRadius: 10)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'VARIO GLOW',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: FittedBox(
                fit: BoxFit.contain,
                child: Text(
                  '${climbRateMs >= 0 ? '+' : ''}${climbRateMs.toStringAsFixed(1)} m/s',
                  style: TextStyle(
                    color: color,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
