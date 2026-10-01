import 'package:flutter/material.dart';

import '../../../../domain/models/grid_spec.dart';
import '../../../../domain/use_cases/alignment_detector.dart';
import '../../../core/theme/cockpit_tokens.dart';

/// Paints the 16x32 edit grid in a single layer. Repaints only when the cell
/// geometry changes (never on telemetry or selection changes).
class GridPainter extends CustomPainter {
  GridPainter({required this.cellWidth, required this.cellHeight});

  final double cellWidth;
  final double cellHeight;

  static final Paint _minor = Paint()
    ..color = CockpitTokens.glassCyan.withAlpha(22)
    ..strokeWidth = 1;
  static final Paint _major = Paint()
    ..color = CockpitTokens.glassCyan.withAlpha(55)
    ..strokeWidth = 1;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 ||
        size.height <= 0 ||
        cellWidth <= 0 ||
        cellHeight <= 0) {
      return;
    }
    for (var col = 1; col < GridSpec.columns; col++) {
      final x = col * cellWidth;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        col % 4 == 0 ? _major : _minor,
      );
    }
    for (var row = 1; row < GridSpec.rows; row++) {
      final y = row * cellHeight;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        row % 4 == 0 ? _major : _minor,
      );
    }
  }

  @override
  bool shouldRepaint(GridPainter old) =>
      old.cellWidth != cellWidth || old.cellHeight != cellHeight;
}

/// Paints alignment guides and overlap highlights for the edited widget.
class GuidePainter extends CustomPainter {
  GuidePainter({
    required this.cellWidth,
    required this.cellHeight,
    required this.result,
  });

  final double cellWidth;
  final double cellHeight;
  final AlignmentResult result;

  static final Paint _guide = Paint()
    ..color = CockpitTokens.glassCyan
    ..strokeWidth = 1.5;
  static final Paint _overlapFill = Paint()
    ..color = CockpitTokens.cautionAmber.withAlpha(70);
  static final Paint _overlapStroke = Paint()
    ..color = CockpitTokens.cautionAmber
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0 || result.isEmpty) return;
    for (final o in result.overlaps) {
      final rect = Rect.fromLTWH(
        o.x * cellWidth,
        o.y * cellHeight,
        o.w * cellWidth,
        o.h * cellHeight,
      );
      canvas.drawRect(rect, _overlapFill);
      canvas.drawRect(rect, _overlapStroke);
    }
    for (final g in result.guides) {
      if (g.axis == GuideAxis.vertical) {
        final x = g.position * cellWidth;
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), _guide);
      } else {
        final y = g.position * cellHeight;
        canvas.drawLine(Offset(0, y), Offset(size.width, y), _guide);
      }
    }
  }

  @override
  bool shouldRepaint(GuidePainter old) =>
      !identical(old.result, result) ||
      old.cellWidth != cellWidth ||
      old.cellHeight != cellHeight;
}
