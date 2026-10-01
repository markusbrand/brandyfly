import '../models/ui_config.dart';

/// Resolves which map widget each map control widget drives and which maps
/// should show their built-in controls. Pure; works on one layout variant.
class MapControlResolver {
  const MapControlResolver();

  /// Bottom-most map widget in the stack, or null.
  String? autoTargetId(List<WidgetPlacementModel> widgets) {
    for (final w in widgets) {
      if (w.type == WidgetType.map) return w.id;
    }
    return null;
  }

  /// Map widget id driven by [control], or null when no valid target exists.
  String? resolveTarget(
    List<WidgetPlacementModel> widgets,
    WidgetPlacementModel control,
  ) {
    if (!control.type.isMapControl) return null;
    final target = control.effectiveMapControlTarget;
    if (target == kAutoMapTarget) return autoTargetId(widgets);
    for (final w in widgets) {
      if (w.id == target && w.type == WidgetType.map) return w.id;
    }
    return null;
  }

  /// True when [control] has an explicit target that no longer exists.
  bool isTargetMissing(
    List<WidgetPlacementModel> widgets,
    WidgetPlacementModel control,
  ) {
    final target = control.effectiveMapControlTarget;
    if (target == kAutoMapTarget) return false;
    return resolveTarget(widgets, control) == null;
  }

  /// Map ids targeted by at least one map control widget.
  Set<String> mapsWithExternalControls(List<WidgetPlacementModel> widgets) {
    final result = <String>{};
    final auto = autoTargetId(widgets);
    for (final w in widgets) {
      if (!w.type.isMapControl) continue;
      final target = w.effectiveMapControlTarget;
      if (target == kAutoMapTarget) {
        if (auto != null) result.add(auto);
      } else {
        for (final m in widgets) {
          if (m.id == target && m.type == WidgetType.map) {
            result.add(m.id);
            break;
          }
        }
      }
    }
    return result;
  }

  /// Whether [map] should render its built-in zoom / recenter buttons.
  bool builtInControlsVisible(
    WidgetPlacementModel map,
    Set<String> mapsWithExternalControls,
  ) {
    switch (map.effectiveMapBuiltInControls) {
      case MapBuiltInControls.always:
        return true;
      case MapBuiltInControls.never:
        return false;
      case MapBuiltInControls.auto:
        return !mapsWithExternalControls.contains(map.id);
    }
  }
}
