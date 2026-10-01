import 'package:flutter/material.dart';

import '../../../../domain/models/ui_config.dart';
import '../../../core/theme/cockpit_tokens.dart';

/// Background treatment of a layout strategy (one widget per strategy instead
/// of three duplicated layout builders).
class StrategyBackdrop extends StatelessWidget {
  const StrategyBackdrop({
    super.key,
    required this.strategy,
    required this.isEditMode,
    required this.cellWidth,
  });

  final LayoutStrategyStyle strategy;
  final bool isEditMode;
  final double cellWidth;

  @override
  Widget build(BuildContext context) {
    switch (strategy) {
      case LayoutStrategyStyle.freeformHud:
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(30),
            border: isEditMode
                ? Border.all(
                    color: CockpitTokens.glassCyan.withAlpha(60),
                    width: 2,
                  )
                : null,
          ),
          child: isEditMode
              ? const _StrategyLabel('FREEFORM HUD (SCREEN CONFIGURATION)')
              : const SizedBox.expand(),
        );
      case LayoutStrategyStyle.snapToGrid:
        return ColoredBox(
          color: Colors.blueGrey.shade900.withAlpha(80),
          child: isEditMode
              ? const _StrategyLabel('SNAP TO GRID')
              : const SizedBox.expand(),
        );
      case LayoutStrategyStyle.sidebarDashboard:
        return ColoredBox(
          color: Colors.black.withAlpha(20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: cellWidth * 4,
              height: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade900.withAlpha(60),
                  border: Border(
                    right: BorderSide(
                      color: isEditMode
                          ? CockpitTokens.glassCyan.withAlpha(80)
                          : Colors.white.withAlpha(20),
                      width: 1.5,
                    ),
                  ),
                ),
                child: isEditMode
                    ? const Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'SIDEBAR',
                            style: TextStyle(
                              color: Color(0x803FE0F0),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                      )
                    : null,
              ),
            ),
          ),
        );
    }
  }
}

class _StrategyLabel extends StatelessWidget {
  const _StrategyLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: CockpitTokens.glassCyan.withAlpha(120),
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
