import 'package:flutter/material.dart';

import '../../../../domain/models/size_tier.dart';
import '../../../../domain/models/ui_config.dart';
import '../../../core/theme/cockpit_tokens.dart';

/// Numeric flight instrument (altitude, speed, glide, HAG).
///
/// Content follows the size tier: tiny = value only, compact = value + unit,
/// regular = label + value + unit. When [tier] is null it is derived from the
/// widget's own constraints. Only the value digits are scaled with FittedBox.
class NumericTextWidget extends StatelessWidget {
  const NumericTextWidget({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.style,
    this.tier,
  });

  final String label;
  final String value;
  final String unit;
  final NumericWidgetStyle style;
  final SizeTier? tier;

  @override
  Widget build(BuildContext context) {
    final semanticValue = unit.isNotEmpty
        ? '$label: $value $unit'
        : '$label: $value';
    return Semantics(
      label: semanticValue,
      readOnly: true,
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxHeight < 6 || constraints.maxWidth < 6) {
            return const SizedBox.shrink();
          }
          final effectiveTier =
              tier ?? sizeTierFor(constraints.maxWidth, constraints.maxHeight);
          return SizedBox.expand(child: _buildStyled(effectiveTier));
        },
      ),
    );
  }

  _NumericPalette get _palette {
    switch (style) {
      case NumericWidgetStyle.minimalistText:
        return const _NumericPalette(
          background: Color(0xA0000000),
          value: CockpitTokens.ink,
          label: CockpitTokens.inkMuted,
          unit: CockpitTokens.inkMuted,
        );
      case NumericWidgetStyle.highContrastBox:
        return _NumericPalette(
          background: Colors.yellow.shade400,
          value: Colors.black,
          label: Colors.black,
          unit: Colors.black,
          border: const BorderSide(color: Colors.black, width: 2),
          joinUnit: true,
        );
      case NumericWidgetStyle.circularGauge:
        return _NumericPalette(
          background: Colors.blueGrey.shade900,
          value: CockpitTokens.ink,
          label: CockpitTokens.glassCyan,
          unit: CockpitTokens.inkMuted,
          border: const BorderSide(color: CockpitTokens.glassCyan, width: 1.5),
          circular: true,
        );
      case NumericWidgetStyle.retroDigital:
        return _NumericPalette(
          background: Colors.black,
          value: Colors.greenAccent.shade400,
          label: Colors.greenAccent.shade200,
          unit: Colors.greenAccent.shade400,
          border: BorderSide(color: Colors.greenAccent.shade400, width: 1.2),
          joinUnit: true,
          glow: true,
        );
    }
  }

  Widget _buildStyled(SizeTier tier) {
    final palette = _palette;
    final valueStyle = CockpitTokens.instrumentValue.copyWith(
      color: palette.value,
      fontSize: 42,
      shadows: palette.glow
          ? [Shadow(color: palette.value, blurRadius: 6)]
          : null,
    );
    final unitStyle = CockpitTokens.instrumentLabel.copyWith(
      color: palette.unit,
      fontSize: 16,
      letterSpacing: 0,
    );

    // Value (and unit) are the only parts scaled to fill the box.
    final Widget valueRow;
    if (tier == SizeTier.tiny || unit.isEmpty) {
      valueRow = Text(value, style: valueStyle, maxLines: 1);
    } else if (palette.joinUnit) {
      valueRow = Text('$value $unit', style: valueStyle, maxLines: 1);
    } else {
      valueRow = Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(value, style: valueStyle, maxLines: 1),
          const SizedBox(width: 3),
          Text(unit, style: unitStyle, maxLines: 1),
        ],
      );
    }

    final alignment = palette.circular
        ? Alignment.center
        : Alignment.centerLeft;
    final scaledValue = FittedBox(
      fit: BoxFit.contain,
      alignment: alignment,
      child: valueRow,
    );

    final Widget content;
    if (tier == SizeTier.regular) {
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: palette.circular
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.stretch,
        children: [
          Text(
            label.toUpperCase(),
            style: CockpitTokens.instrumentLabel.copyWith(
              color: palette.label,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: palette.circular ? TextAlign.center : TextAlign.start,
          ),
          Expanded(child: scaledValue),
        ],
      );
    } else {
      content = scaledValue;
    }

    final padding = tier == SizeTier.tiny
        ? const EdgeInsets.all(1.5)
        : const EdgeInsets.symmetric(horizontal: 3, vertical: 2);

    return Container(
      padding: palette.circular && tier != SizeTier.tiny
          ? const EdgeInsets.all(6)
          : padding,
      decoration: BoxDecoration(
        color: palette.background,
        shape: palette.circular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: palette.circular ? null : BorderRadius.circular(6),
        border: palette.border == null
            ? null
            : Border.fromBorderSide(palette.border!),
      ),
      child: content,
    );
  }
}

class _NumericPalette {
  const _NumericPalette({
    required this.background,
    required this.value,
    required this.label,
    required this.unit,
    this.border,
    this.joinUnit = false,
    this.circular = false,
    this.glow = false,
  });

  final Color background;
  final Color value;
  final Color label;
  final Color unit;
  final BorderSide? border;
  final bool joinUnit;
  final bool circular;
  final bool glow;
}
