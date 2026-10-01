import '../models/ui_config.dart';
import '../models/widget_catalog.dart';
import 'layout_editor.dart';

/// Axis of an alignment guide.
enum GuideAxis { vertical, horizontal }

/// An alignment guide line in grid units (may be fractional for centers).
class AlignmentGuide {
  const AlignmentGuide(this.axis, this.position);
  final GuideAxis axis;
  final double position;

  @override
  bool operator ==(Object other) =>
      other is AlignmentGuide &&
      other.axis == axis &&
      other.position == position;

  @override
  int get hashCode => Object.hash(axis, position);

  @override
  String toString() => 'Guide(${axis.name} @ $position)';
}

/// Result of [AlignmentDetector.detect].
class AlignmentResult {
  const AlignmentResult({this.guides = const [], this.overlaps = const []});
  final List<AlignmentGuide> guides;
  final List<GridRect> overlaps;

  bool get isEmpty => guides.isEmpty && overlaps.isEmpty;

  static const AlignmentResult none = AlignmentResult();
}

/// Finds edge/center alignments and overlaps for an edited widget.
class AlignmentDetector {
  const AlignmentDetector();

  AlignmentResult detect(
    List<WidgetPlacementModel> widgets,
    String editedId, {
    bool includeGuides = true,
  }) {
    WidgetPlacementModel? edited;
    for (final w in widgets) {
      if (w.id == editedId) {
        edited = w;
        break;
      }
    }
    if (edited == null) return AlignmentResult.none;

    final e = GridRect(edited.x, edited.y, edited.w, edited.h);
    final vertical = <double>{};
    final horizontal = <double>{};
    final overlaps = <GridRect>[];

    final eX = <double>[e.x.toDouble(), e.x + e.w / 2, e.right.toDouble()];
    final eY = <double>[e.y.toDouble(), e.y + e.h / 2, e.bottom.toDouble()];

    void collect(List<double> mine, List<double> theirs, Set<double> out) {
      for (final m in mine) {
        for (final t in theirs) {
          if (m == t) out.add(m);
        }
      }
    }

    if (includeGuides) {
      // Canvas center lines.
      collect(eX, const [GridSpec.columns / 2], vertical);
      collect(eY, const [GridSpec.rows / 2], horizontal);
    }

    for (final other in widgets) {
      if (other.id == editedId) continue;
      final o = GridRect(other.x, other.y, other.w, other.h);
      final background = isFullCanvasBackground(other);
      if (includeGuides && !background) {
        collect(
          eX,
          [o.x.toDouble(), o.x + o.w / 2, o.right.toDouble()],
          vertical,
        );
        collect(
          eY,
          [o.y.toDouble(), o.y + o.h / 2, o.bottom.toDouble()],
          horizontal,
        );
      }
      if (!background) {
        final overlap = e.intersection(o);
        if (overlap != null) overlaps.add(overlap);
      }
    }

    final guides = <AlignmentGuide>[
      for (final v in vertical.toList()..sort())
        AlignmentGuide(GuideAxis.vertical, v),
      for (final h in horizontal.toList()..sort())
        AlignmentGuide(GuideAxis.horizontal, h),
    ];
    return AlignmentResult(guides: guides, overlaps: overlaps);
  }
}
