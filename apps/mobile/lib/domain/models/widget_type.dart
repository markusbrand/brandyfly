/// All placeable flight widget types.
///
/// Kept in its own file without dependencies so the widget catalog and the
/// layout migrator can use it without importing the full UI config model.
enum WidgetType {
  altitude,
  speed,
  glide,
  hag,
  windDirection,
  varioBar,
  altitudeChart,
  map,
  thermalMap,
  mapZoomIn,
  mapZoomOut,
  mapZoomRocker,
  mapRecenter,
}

extension WidgetTypeX on WidgetType {
  /// Full-canvas background style widgets (placed at the back of the stack).
  bool get isMapLike => this == WidgetType.map || this == WidgetType.thermalMap;

  /// Placeable controls that drive a map camera.
  bool get isMapControl =>
      this == WidgetType.mapZoomIn ||
      this == WidgetType.mapZoomOut ||
      this == WidgetType.mapZoomRocker ||
      this == WidgetType.mapRecenter;

  bool get isNumeric =>
      this == WidgetType.altitude ||
      this == WidgetType.speed ||
      this == WidgetType.glide ||
      this == WidgetType.hag;

  /// Human readable short name used in edit chrome.
  String get displayName {
    switch (this) {
      case WidgetType.altitude:
        return 'Altitude';
      case WidgetType.speed:
        return 'Speed';
      case WidgetType.glide:
        return 'Glide';
      case WidgetType.hag:
        return 'HAG';
      case WidgetType.windDirection:
        return 'Wind';
      case WidgetType.varioBar:
        return 'Vario';
      case WidgetType.altitudeChart:
        return 'Alt chart';
      case WidgetType.map:
        return 'Map';
      case WidgetType.thermalMap:
        return 'Thermal map';
      case WidgetType.mapZoomIn:
        return 'Zoom in';
      case WidgetType.mapZoomOut:
        return 'Zoom out';
      case WidgetType.mapZoomRocker:
        return 'Zoom rocker';
      case WidgetType.mapRecenter:
        return 'Recenter';
    }
  }
}

/// Parses a widget type name, returning null for unknown names.
WidgetType? widgetTypeFromName(Object? name) {
  if (name is! String) return null;
  for (final t in WidgetType.values) {
    if (t.name == name) return t;
  }
  return null;
}
