import '../models/ui_config.dart';
import '../models/widget_catalog.dart';

/// Pure layout editing rules shared by every editing path (drag, steppers,
/// inspector, configuration sheet, presets, picker).
///
/// All operations take a widget list (one layout variant) and return a new
/// list. When an operation has no effect, the *identical* input list is
/// returned so callers can skip notifications and persistence.
class LayoutEditor {
  const LayoutEditor();

  int indexOf(List<WidgetPlacementModel> list, String id) {
    for (var i = 0; i < list.length; i++) {
      if (list[i].id == id) return i;
    }
    return -1;
  }

  /// Clamps a placement into the grid, type minimum size and (for interactive
  /// widgets) the 48 dp touch target for [geometry].
  WidgetPlacementModel clamp(
    WidgetPlacementModel p, {
    CellGeometry? geometry,
  }) {
    final r = clampGridRect(
      p.type,
      GridRect(p.x, p.y, p.w, p.h),
      geometry: geometry,
    );
    if (r.x == p.x && r.y == p.y && r.w == p.w && r.h == p.h) return p;
    return p.copyWith(x: r.x, y: r.y, w: r.w, h: r.h);
  }

  /// Replaces the placement with the same id (clamped). Used by the config
  /// sheet to apply style and bounds changes at once.
  List<WidgetPlacementModel> update(
    List<WidgetPlacementModel> list,
    WidgetPlacementModel placement, {
    CellGeometry? geometry,
  }) {
    final index = indexOf(list, placement.id);
    if (index == -1) return list;
    final sanitized = clamp(placement, geometry: geometry);
    if (sanitized == list[index]) return list;
    return List<WidgetPlacementModel>.of(list)..[index] = sanitized;
  }

  List<WidgetPlacementModel> setRect(
    List<WidgetPlacementModel> list,
    String id,
    GridRect rect, {
    CellGeometry? geometry,
  }) {
    final index = indexOf(list, id);
    if (index == -1) return list;
    return update(
      list,
      list[index].copyWith(x: rect.x, y: rect.y, w: rect.w, h: rect.h),
      geometry: geometry,
    );
  }

  /// Moves a widget by whole cells, keeping its size.
  List<WidgetPlacementModel> move(
    List<WidgetPlacementModel> list,
    String id,
    int dx,
    int dy, {
    CellGeometry? geometry,
  }) {
    final index = indexOf(list, id);
    if (index == -1 || (dx == 0 && dy == 0)) return list;
    final p = clamp(list[index], geometry: geometry);
    final x = (p.x + dx).clamp(0, GridSpec.columns - p.w);
    final y = (p.y + dy).clamp(0, GridSpec.rows - p.h);
    return setRect(list, id, GridRect(x, y, p.w, p.h), geometry: geometry);
  }

  /// Resizes a widget by whole cells, anchored at its top-left corner. Growth
  /// stops at the canvas edge rather than shifting the widget.
  List<WidgetPlacementModel> resize(
    List<WidgetPlacementModel> list,
    String id,
    int dw,
    int dh, {
    CellGeometry? geometry,
  }) {
    final index = indexOf(list, id);
    if (index == -1 || (dw == 0 && dh == 0)) return list;
    final p = clamp(list[index], geometry: geometry);
    final min = effectiveMinSize(p.type, geometry: geometry);
    final w = (p.w + dw).clamp(min.w, GridSpec.columns - p.x < min.w
        ? min.w
        : GridSpec.columns - p.x);
    final h = (p.h + dh).clamp(min.h, GridSpec.rows - p.y < min.h
        ? min.h
        : GridSpec.rows - p.y);
    return setRect(list, id, GridRect(p.x, p.y, w, h), geometry: geometry);
  }

  /// Applies a catalog size preset, keeping the top-left corner where possible
  /// and shifting inward only as needed to stay inside the grid.
  List<WidgetPlacementModel> applyPreset(
    List<WidgetPlacementModel> list,
    String id,
    SizePreset preset, {
    CellGeometry? geometry,
  }) {
    final index = indexOf(list, id);
    if (index == -1) return list;
    final p = list[index];
    final size = specFor(p.type).presets[preset];
    if (size == null) return list;
    final x = p.x.clamp(0, GridSpec.columns - size.w);
    final y = p.y.clamp(0, GridSpec.rows - size.h);
    return setRect(list, id, GridRect(x, y, size.w, size.h), geometry: geometry);
  }

  /// True when an interactive widget renders below 48 dp on [geometry].
  bool isBelowTouchTarget(WidgetPlacementModel p, CellGeometry geometry) {
    if (!specFor(p.type).interactive || !geometry.isKnown) return false;
    return p.w * geometry.cellWidth < GridSpec.minTouchTargetDp - 1e-6 ||
        p.h * geometry.cellHeight < GridSpec.minTouchTargetDp - 1e-6;
  }

  /// Grows an interactive widget to the smallest size that keeps a 48 dp
  /// touch target on [geometry].
  List<WidgetPlacementModel> fixTouchSize(
    List<WidgetPlacementModel> list,
    String id,
    CellGeometry geometry,
  ) {
    final index = indexOf(list, id);
    if (index == -1) return list;
    return update(list, list[index], geometry: geometry);
  }

  /// Creates a new placement for [type] with catalog defaults.
  ///
  /// Map-like widgets go to the back of the stack at (0,0); everything else is
  /// appended to the front at the first position not overlapping another
  /// non-background widget (or (0,0) when none is free).
  List<WidgetPlacementModel> add(
    List<WidgetPlacementModel> list,
    WidgetType type,
    String id, {
    CellGeometry? geometry,
  }) {
    final spec = specFor(type);
    final min = effectiveMinSize(type, geometry: geometry);
    final w = spec.defaultSize.w < min.w ? min.w : spec.defaultSize.w;
    final h = spec.defaultSize.h < min.h ? min.h : spec.defaultSize.h;
    final origin = type.isMapLike
        ? const GridRect(0, 0, 0, 0)
        : _firstFreeSlot(list, w, h);

    final placement = WidgetPlacementModel(
      id: id,
      type: type,
      x: origin.x,
      y: origin.y,
      w: w,
      h: h,
      numericStyle: type.isNumeric ? NumericWidgetStyle.minimalistText : null,
      windStyle: type == WidgetType.windDirection
          ? WindWidgetStyle.relativeArrow
          : null,
      varioStyle: type == WidgetType.varioBar
          ? LiftSinkBarStyle.verticalEdgeBar
          : null,
      altitudeChartStyle: type == WidgetType.altitudeChart
          ? AltitudeChartStyle.minimalSparkline
          : null,
      mapStyle: type == WidgetType.map ? MapWidgetStyle.topoContours : null,
      mapOrientation: type == WidgetType.map ? MapOrientation.trackUp : null,
      mapShowAirspace: type == WidgetType.map ? true : null,
      mapShowThermals: type == WidgetType.map ? true : null,
      mapShowTrack: type == WidgetType.map ? true : null,
      mapShowContours: type == WidgetType.map ? true : null,
      mapTrackHistoryMinutes: type == WidgetType.map ? 10 : null,
      mapTrackShowOlderTail: type == WidgetType.map ? true : null,
      mapBuiltInControls: type == WidgetType.map
          ? MapBuiltInControls.auto
          : null,
      thermalMapStyle: type == WidgetType.thermalMap
          ? ThermalMapStyle.xctrackBubbles
          : null,
      thermalMapShowCore: type == WidgetType.thermalMap ? true : null,
      thermalMapHistorySeconds: type == WidgetType.thermalMap ? 90 : null,
      mapControlTarget: type.isMapControl ? kAutoMapTarget : null,
    );
    final sanitized = clamp(placement, geometry: geometry);
    return type.isMapLike ? [sanitized, ...list] : [...list, sanitized];
  }

  GridRect _firstFreeSlot(List<WidgetPlacementModel> list, int w, int h) {
    final occupied = [
      for (final p in list)
        if (!isFullCanvasBackground(p)) GridRect(p.x, p.y, p.w, p.h),
    ];
    for (var y = 0; y + h <= GridSpec.rows; y++) {
      for (var x = 0; x + w <= GridSpec.columns; x++) {
        final candidate = GridRect(x, y, w, h);
        var free = true;
        for (final o in occupied) {
          if (candidate.intersects(o)) {
            free = false;
            break;
          }
        }
        if (free) return candidate;
      }
    }
    return GridRect(0, 0, w, h);
  }

  List<WidgetPlacementModel> remove(List<WidgetPlacementModel> list, String id) {
    final index = indexOf(list, id);
    if (index == -1) return list;
    return List<WidgetPlacementModel>.of(list)..removeAt(index);
  }

  List<WidgetPlacementModel> bringToFront(
    List<WidgetPlacementModel> list,
    String id,
  ) => _reorder(list, id, (i, n) => n - 1);

  List<WidgetPlacementModel> bringForward(
    List<WidgetPlacementModel> list,
    String id,
  ) => _reorder(list, id, (i, n) => i + 1);

  List<WidgetPlacementModel> sendBackward(
    List<WidgetPlacementModel> list,
    String id,
  ) => _reorder(list, id, (i, n) => i - 1);

  List<WidgetPlacementModel> sendToBack(
    List<WidgetPlacementModel> list,
    String id,
  ) => _reorder(list, id, (i, n) => 0);

  List<WidgetPlacementModel> _reorder(
    List<WidgetPlacementModel> list,
    String id,
    int Function(int index, int length) target,
  ) {
    final index = indexOf(list, id);
    if (index == -1) return list;
    final to = target(index, list.length).clamp(0, list.length - 1);
    if (to == index) return list;
    final updated = List<WidgetPlacementModel>.of(list);
    final item = updated.removeAt(index);
    updated.insert(to, item);
    return updated;
  }

  /// Copies the tall layout into a new wide layout (same ids, sizes, styles
  /// and stack order).
  List<WidgetPlacementModel> copyForVariant(List<WidgetPlacementModel> tall) =>
      List<WidgetPlacementModel>.unmodifiable(tall);
}

/// Full-canvas background maps are ignored for free-slot search and overlap
/// warnings.
bool isFullCanvasBackground(WidgetPlacementModel p) =>
    p.type.isMapLike &&
    p.x == 0 &&
    p.y == 0 &&
    p.w == GridSpec.columns &&
    p.h == GridSpec.rows;
