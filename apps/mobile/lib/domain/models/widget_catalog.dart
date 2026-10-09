import 'grid_spec.dart';
import 'widget_type.dart';

/// Named size presets offered in the inspector.
enum SizePreset { s, m, l, full }

extension SizePresetX on SizePreset {
  String get label {
    switch (this) {
      case SizePreset.s:
        return 'S';
      case SizePreset.m:
        return 'M';
      case SizePreset.l:
        return 'L';
      case SizePreset.full:
        return 'Full';
    }
  }
}

/// Width/height pair in grid cells.
class GridSize {
  const GridSize(this.w, this.h);
  final int w;
  final int h;

  @override
  bool operator ==(Object other) =>
      other is GridSize && other.w == w && other.h == h;

  @override
  int get hashCode => Object.hash(w, h);

  @override
  String toString() => '${w}x$h';
}

/// Size rules for one widget type.
class WidgetSpec {
  const WidgetSpec({
    required this.minSize,
    required this.defaultSize,
    required this.presets,
    this.interactive = false,
  });

  final GridSize minSize;
  final GridSize defaultSize;
  final Map<SizePreset, GridSize> presets;

  /// Interactive widgets must keep a >= 48 dp touch target.
  final bool interactive;
}

const GridSize _full = GridSize(GridSpec.columns, GridSpec.rows);

const Map<SizePreset, GridSize> _numericPresets = {
  SizePreset.s: GridSize(3, 2),
  SizePreset.m: GridSize(4, 4),
  SizePreset.l: GridSize(8, 5),
  SizePreset.full: GridSize(16, 8),
};

const WidgetSpec _numericSpec = WidgetSpec(
  minSize: GridSize(1, 1),
  defaultSize: GridSize(4, 4),
  presets: _numericPresets,
);

const Map<SizePreset, GridSize> _mapPresets = {
  SizePreset.s: GridSize(8, 8),
  SizePreset.m: GridSize(16, 16),
  SizePreset.l: GridSize(16, 24),
  SizePreset.full: _full,
};

const Map<SizePreset, GridSize> _buttonPresets = {
  SizePreset.s: GridSize(2, 2),
  SizePreset.m: GridSize(3, 3),
  SizePreset.l: GridSize(4, 4),
};

const WidgetSpec _buttonSpec = WidgetSpec(
  minSize: GridSize(1, 1),
  defaultSize: GridSize(3, 3),
  presets: _buttonPresets,
  interactive: true,
);

const Map<SizePreset, GridSize> _sideCutPresets = {
  SizePreset.s: GridSize(16, 6),
  SizePreset.m: GridSize(16, 8),
  SizePreset.l: GridSize(16, 12),
  SizePreset.full: _full,
};

const WidgetSpec _sideCutSpec = WidgetSpec(
  minSize: GridSize(8, 4),
  defaultSize: GridSize(16, 8),
  presets: _sideCutPresets,
);

/// Size rules for every [WidgetType]. Every type MUST have an entry.
const Map<WidgetType, WidgetSpec> widgetCatalog = {
  WidgetType.altitude: _numericSpec,
  WidgetType.speed: _numericSpec,
  WidgetType.glide: _numericSpec,
  WidgetType.hag: _numericSpec,
  WidgetType.windDirection: WidgetSpec(
    minSize: GridSize(2, 2),
    defaultSize: GridSize(5, 5),
    presets: {
      SizePreset.s: GridSize(3, 3),
      SizePreset.m: GridSize(5, 5),
      SizePreset.l: GridSize(8, 8),
      SizePreset.full: GridSize(16, 16),
    },
  ),
  WidgetType.varioBar: WidgetSpec(
    minSize: GridSize(1, 4),
    defaultSize: GridSize(3, 16),
    presets: {
      SizePreset.s: GridSize(2, 8),
      SizePreset.m: GridSize(3, 16),
      SizePreset.l: GridSize(4, 32),
      SizePreset.full: _full,
    },
  ),
  WidgetType.altitudeChart: WidgetSpec(
    minSize: GridSize(2, 2),
    defaultSize: GridSize(8, 4),
    presets: {
      SizePreset.s: GridSize(4, 3),
      SizePreset.m: GridSize(8, 4),
      SizePreset.l: GridSize(16, 6),
      SizePreset.full: _full,
    },
  ),
  WidgetType.map: WidgetSpec(
    minSize: GridSize(4, 4),
    defaultSize: _full,
    presets: _mapPresets,
  ),
  WidgetType.thermalMap: WidgetSpec(
    minSize: GridSize(4, 4),
    defaultSize: _full,
    presets: _mapPresets,
  ),
  WidgetType.mapZoomIn: _buttonSpec,
  WidgetType.mapZoomOut: _buttonSpec,
  WidgetType.mapRecenter: _buttonSpec,
  WidgetType.airspaceSideCut: _sideCutSpec,
  WidgetType.mapZoomRocker: WidgetSpec(
    minSize: GridSize(1, 2),
    defaultSize: GridSize(3, 6),
    presets: {
      SizePreset.s: GridSize(2, 4),
      SizePreset.m: GridSize(3, 6),
      SizePreset.l: GridSize(4, 8),
    },
    interactive: true,
  ),
};

WidgetSpec specFor(WidgetType type) => widgetCatalog[type]!;

/// Integer rectangle on the grid.
class GridRect {
  const GridRect(this.x, this.y, this.w, this.h);
  final int x;
  final int y;
  final int w;
  final int h;

  int get right => x + w;
  int get bottom => y + h;

  bool intersects(GridRect o) =>
      x < o.right && o.x < right && y < o.bottom && o.y < bottom;

  GridRect? intersection(GridRect o) {
    if (!intersects(o)) return null;
    final nx = x > o.x ? x : o.x;
    final ny = y > o.y ? y : o.y;
    final nr = right < o.right ? right : o.right;
    final nb = bottom < o.bottom ? bottom : o.bottom;
    return GridRect(nx, ny, nr - nx, nb - ny);
  }

  @override
  bool operator ==(Object other) =>
      other is GridRect &&
      other.x == x &&
      other.y == y &&
      other.w == w &&
      other.h == h;

  @override
  int get hashCode => Object.hash(x, y, w, h);

  @override
  String toString() => 'GridRect($x,$y ${w}x$h)';
}

/// Effective minimum size of [type], optionally raised so interactive widgets
/// keep a 48 dp touch target for the given [geometry].
GridSize effectiveMinSize(WidgetType type, {CellGeometry? geometry}) {
  final spec = specFor(type);
  var minW = spec.minSize.w;
  var minH = spec.minSize.h;
  if (spec.interactive && geometry != null && geometry.isKnown) {
    if (geometry.touchCellsW > minW) minW = geometry.touchCellsW;
    if (geometry.touchCellsH > minH) minH = geometry.touchCellsH;
  }
  return GridSize(
    minW.clamp(1, GridSpec.columns),
    minH.clamp(1, GridSpec.rows),
  );
}

/// Clamps [rect] into the grid and to the type minimum size.
GridRect clampGridRect(
  WidgetType type,
  GridRect rect, {
  CellGeometry? geometry,
}) {
  final min = effectiveMinSize(type, geometry: geometry);
  final w = rect.w.clamp(min.w, GridSpec.columns);
  final h = rect.h.clamp(min.h, GridSpec.rows);
  final x = rect.x.clamp(0, GridSpec.columns - w);
  final y = rect.y.clamp(0, GridSpec.rows - h);
  return GridRect(x, y, w, h);
}
