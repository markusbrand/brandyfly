import '../models/grid_spec.dart';
import '../models/widget_catalog.dart';
import '../models/widget_type.dart';

/// Migrates persisted screen layouts from older grid resolutions to the
/// current 16x32 grid.
///
/// Operates on raw JSON maps so it can run before model parsing, and contains
/// no Flutter or persistence dependencies.
class LayoutMigrator {
  const LayoutMigrator._();

  /// Grid resolution a stored screen was saved with. Screens without the key
  /// predate the 8-column grid and use the legacy 4-column grid.
  static int storedResolution(Map<String, dynamic> screenJson) {
    final raw = screenJson['gridResolution'];
    return raw is int ? raw : 4;
  }

  /// Returns widget JSON maps migrated to the 16x32 grid.
  ///
  /// Widgets with unknown types or malformed coordinates are dropped.
  static List<Map<String, dynamic>> migrateWidgets(
    List<dynamic> rawWidgets,
    int fromResolution,
  ) {
    final parsed = <_RawWidget>[];
    for (final raw in rawWidgets) {
      if (raw is! Map) continue;
      final json = Map<String, dynamic>.from(raw);
      final type = widgetTypeFromName(json['type']);
      final x = json['x'];
      final y = json['y'];
      final w = json['w'];
      final h = json['h'];
      if (type == null || x is! int || y is! int || w is! int || h is! int) {
        continue;
      }
      parsed.add(_RawWidget(json, type, GridRect(x, y, w, h)));
    }
    if (parsed.isEmpty) return const [];

    var rects = parsed.map((p) => p.rect).toList();
    var resolution = fromResolution;

    // v1 (4 columns) -> v2 (8 columns): scale everything by 2.
    if (resolution < 8) {
      rects = [
        for (final r in rects) GridRect(r.x * 2, r.y * 2, r.w * 2, r.h * 2),
      ];
      resolution = 8;
    }

    // v2 (8 columns, dynamic rows) -> v3 (16x32).
    if (resolution < GridSpec.columns) {
      var effectiveRows = 8;
      for (final r in rects) {
        if (r.bottom > effectiveRows) effectiveRows = r.bottom;
      }
      rects = [for (final r in rects) mapRect8To16(r, effectiveRows)];
    }

    return [
      for (var i = 0; i < parsed.length; i++)
        _withRect(
          parsed[i].json,
          clampGridRect(parsed[i].type, rects[i]),
        ),
    ];
  }

  /// Maps one rectangle from the 8-column grid with [effectiveRows] rows to
  /// the 16x32 grid, keeping vertical edges proportional.
  static GridRect mapRect8To16(GridRect r, int effectiveRows) {
    final rows = effectiveRows <= 0 ? 8 : effectiveRows;
    final y = (r.y * GridSpec.rows / rows).round();
    final bottom = (r.bottom * GridSpec.rows / rows).round();
    final h = bottom - y < 1 ? 1 : bottom - y;
    return GridRect(r.x * 2, y, r.w * 2, h);
  }

  static Map<String, dynamic> _withRect(Map<String, dynamic> json, GridRect r) {
    return {...json, 'x': r.x, 'y': r.y, 'w': r.w, 'h': r.h};
  }
}

class _RawWidget {
  _RawWidget(this.json, this.type, this.rect);
  final Map<String, dynamic> json;
  final WidgetType type;
  final GridRect rect;
}
