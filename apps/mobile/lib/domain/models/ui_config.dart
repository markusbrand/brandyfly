import 'dart:convert';

import '../thermal/thermal_variant.dart';
import '../use_cases/layout_migrator.dart';
import 'grid_spec.dart';
import 'widget_type.dart';

export '../thermal/thermal_variant.dart' show ThermalSeason, ThermalTimeOfDay;
export 'grid_spec.dart';
export 'widget_type.dart';

enum NavBarStyle {
  translucentDrawer, // Option 1 (Default)
  floatingPill, // Option 2
  cornerMenu, // Option 3
}

enum LayoutStrategyStyle {
  freeformHud, // Option 1
  snapToGrid, // Option 2
  sidebarDashboard, // Option 3 (Default)
}

enum ScreenAutoSwitchTrigger {
  manualOnly, // Option 1 (Default)
  onThermalCircling, // Option 2
  onGlideStraight, // Option 3
}

enum NumericWidgetStyle {
  minimalistText, // Option 1 (Default)
  highContrastBox, // Option 2
  circularGauge, // Option 3
  retroDigital, // Option 4
}

enum WindWidgetStyle {
  relativeArrow, // Option 1 (Default)
  miniCompassRose, // Option 2
  windsockIndicator, // Option 3
}

enum LiftSinkBarStyle {
  verticalEdgeBar, // Option 1 (Default)
  analogDial, // Option 2
  screenEdgeGlow, // Option 3
}

enum AltitudeChartStyle {
  minimalSparkline, // Option 1 (Default)
  filledAreaGraph, // Option 2
  detailedGrid, // Option 3
}

enum MapWidgetStyle {
  alpineRelief, // Option 1 (Default)
  topoContours, // Option 2
  minimalVector, // Option 3
  thermalHeatmap, // Option 4
  satelliteTerrain, // Option 5
}

enum MapOrientation {
  northUp, // Option 1
  trackUp, // Option 2 (Default)
  headingUp, // Option 3
}

enum ThermalingStyle {
  zoomedRadar, // Option 1
  focusMode, // Option 2
  assistantDisplay, // Option 3 (Default)
}

enum ThermalMapStyle {
  xctrackBubbles, // Option 1 (Default)
  burnairCore, // Option 2
  navigatorRibbon, // Option 3
}

enum SettingsStyle {
  modalOverlay, // Option 1
  categorizedList, // Option 2 (Default)
  cardDashboard, // Option 3
}

/// Visibility policy of a map widget's built-in zoom / recenter buttons.
enum MapBuiltInControls {
  /// Hidden while at least one map control widget targets this map.
  auto,
  always,
  never,
}

/// Target value meaning "the bottom-most map on the same layout variant".
const String kAutoMapTarget = 'auto';

class WidgetPlacementModel {
  const WidgetPlacementModel({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    this.numericStyle,
    this.windStyle,
    this.varioStyle,
    this.altitudeChartStyle,
    this.mapStyle,
    this.mapOrientation,
    this.mapShowAirspace,
    this.mapShowThermals,
    this.mapShowTrack,
    this.mapShowContours,
    this.mapZoomLevel,
    this.thermalMapStyle,
    this.thermalMapShowCore,
    this.thermalMapHistorySeconds,
    this.mapTrackHistoryMinutes,
    this.mapTrackShowOlderTail,
    this.mapControlTarget,
    this.mapBuiltInControls,
    this.mapThermalSeason,
    this.mapThermalTimeOfDay,
    this.mapThermalOpacity,
  });

  /// Default KK7 thermal heatmap opacity (60 %).
  static const double defaultThermalOpacity = 0.6;

  final String id;
  final WidgetType type;
  final int x;
  final int y;
  final int w;
  final int h;

  // Widget-specific visual styling options
  final NumericWidgetStyle? numericStyle;
  final WindWidgetStyle? windStyle;
  final LiftSinkBarStyle? varioStyle;
  final AltitudeChartStyle? altitudeChartStyle;
  final MapWidgetStyle? mapStyle;
  final MapOrientation? mapOrientation;
  final bool? mapShowAirspace;
  final bool? mapShowThermals;
  final bool? mapShowTrack;
  final bool? mapShowContours;
  final double? mapZoomLevel;
  final ThermalMapStyle? thermalMapStyle;
  final bool? thermalMapShowCore;
  final int? thermalMapHistorySeconds;
  final int? mapTrackHistoryMinutes;
  final bool? mapTrackShowOlderTail;

  /// For map control widgets: target map widget id or [kAutoMapTarget].
  final String? mapControlTarget;

  /// For map widgets: built-in control visibility policy.
  final MapBuiltInControls? mapBuiltInControls;

  /// For map widgets: KK7 thermal heatmap season (null = auto).
  final ThermalSeason? mapThermalSeason;

  /// For map widgets: KK7 thermal heatmap time of day (null = auto).
  final ThermalTimeOfDay? mapThermalTimeOfDay;

  /// For map widgets: KK7 thermal heatmap opacity 0.1-1.0 (null = 0.6).
  final double? mapThermalOpacity;

  // Fallback defaults
  NumericWidgetStyle get effectiveNumericStyle =>
      numericStyle ?? NumericWidgetStyle.minimalistText;
  WindWidgetStyle get effectiveWindStyle =>
      windStyle ?? WindWidgetStyle.relativeArrow;
  LiftSinkBarStyle get effectiveVarioStyle =>
      varioStyle ?? LiftSinkBarStyle.verticalEdgeBar;
  AltitudeChartStyle get effectiveAltitudeChartStyle =>
      altitudeChartStyle ?? AltitudeChartStyle.minimalSparkline;
  MapWidgetStyle get effectiveMapStyle =>
      mapStyle ?? MapWidgetStyle.topoContours;
  MapOrientation get effectiveMapOrientation =>
      mapOrientation ?? MapOrientation.trackUp;
  bool get effectiveMapShowAirspace => mapShowAirspace ?? true;
  bool get effectiveMapShowThermals => mapShowThermals ?? true;
  bool get effectiveMapShowTrack => mapShowTrack ?? true;
  bool get effectiveMapShowContours => mapShowContours ?? true;
  double get effectiveMapZoomLevel => mapZoomLevel ?? 13.5;
  ThermalMapStyle get effectiveThermalMapStyle =>
      thermalMapStyle ?? ThermalMapStyle.xctrackBubbles;
  bool get effectiveThermalMapShowCore => thermalMapShowCore ?? true;
  int get effectiveThermalMapHistorySeconds => thermalMapHistorySeconds ?? 90;
  int get effectiveMapTrackHistoryMinutes =>
      mapTrackHistoryMinutes ?? 10; // 0 = full flight
  bool get effectiveMapTrackShowOlderTail => mapTrackShowOlderTail ?? true;
  String get effectiveMapControlTarget => mapControlTarget ?? kAutoMapTarget;
  MapBuiltInControls get effectiveMapBuiltInControls =>
      mapBuiltInControls ?? MapBuiltInControls.auto;
  ThermalSeason get effectiveMapThermalSeason =>
      mapThermalSeason ?? ThermalSeason.auto;
  ThermalTimeOfDay get effectiveMapThermalTimeOfDay =>
      mapThermalTimeOfDay ?? ThermalTimeOfDay.auto;
  double get effectiveMapThermalOpacity =>
      (mapThermalOpacity ?? defaultThermalOpacity).clamp(0.1, 1.0);

  WidgetPlacementModel copyWith({
    String? id,
    WidgetType? type,
    int? x,
    int? y,
    int? w,
    int? h,
    NumericWidgetStyle? numericStyle,
    WindWidgetStyle? windStyle,
    LiftSinkBarStyle? varioStyle,
    AltitudeChartStyle? altitudeChartStyle,
    MapWidgetStyle? mapStyle,
    MapOrientation? mapOrientation,
    bool? mapShowAirspace,
    bool? mapShowThermals,
    bool? mapShowTrack,
    bool? mapShowContours,
    double? mapZoomLevel,
    ThermalMapStyle? thermalMapStyle,
    bool? thermalMapShowCore,
    int? thermalMapHistorySeconds,
    int? mapTrackHistoryMinutes,
    bool? mapTrackShowOlderTail,
    String? mapControlTarget,
    MapBuiltInControls? mapBuiltInControls,
    ThermalSeason? mapThermalSeason,
    ThermalTimeOfDay? mapThermalTimeOfDay,
    double? mapThermalOpacity,
  }) {
    return WidgetPlacementModel(
      id: id ?? this.id,
      type: type ?? this.type,
      x: x ?? this.x,
      y: y ?? this.y,
      w: w ?? this.w,
      h: h ?? this.h,
      numericStyle: numericStyle ?? this.numericStyle,
      windStyle: windStyle ?? this.windStyle,
      varioStyle: varioStyle ?? this.varioStyle,
      altitudeChartStyle: altitudeChartStyle ?? this.altitudeChartStyle,
      mapStyle: mapStyle ?? this.mapStyle,
      mapOrientation: mapOrientation ?? this.mapOrientation,
      mapShowAirspace: mapShowAirspace ?? this.mapShowAirspace,
      mapShowThermals: mapShowThermals ?? this.mapShowThermals,
      mapShowTrack: mapShowTrack ?? this.mapShowTrack,
      mapShowContours: mapShowContours ?? this.mapShowContours,
      mapZoomLevel: mapZoomLevel ?? this.mapZoomLevel,
      thermalMapStyle: thermalMapStyle ?? this.thermalMapStyle,
      thermalMapShowCore: thermalMapShowCore ?? this.thermalMapShowCore,
      thermalMapHistorySeconds:
          thermalMapHistorySeconds ?? this.thermalMapHistorySeconds,
      mapTrackHistoryMinutes:
          mapTrackHistoryMinutes ?? this.mapTrackHistoryMinutes,
      mapTrackShowOlderTail:
          mapTrackShowOlderTail ?? this.mapTrackShowOlderTail,
      mapControlTarget: mapControlTarget ?? this.mapControlTarget,
      mapBuiltInControls: mapBuiltInControls ?? this.mapBuiltInControls,
      mapThermalSeason: mapThermalSeason ?? this.mapThermalSeason,
      mapThermalTimeOfDay: mapThermalTimeOfDay ?? this.mapThermalTimeOfDay,
      mapThermalOpacity: mapThermalOpacity ?? this.mapThermalOpacity,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'x': x,
    'y': y,
    'w': w,
    'h': h,
    if (numericStyle != null) 'numericStyle': numericStyle!.name,
    if (windStyle != null) 'windStyle': windStyle!.name,
    if (varioStyle != null) 'varioStyle': varioStyle!.name,
    if (altitudeChartStyle != null)
      'altitudeChartStyle': altitudeChartStyle!.name,
    if (mapStyle != null) 'mapStyle': mapStyle!.name,
    if (mapOrientation != null) 'mapOrientation': mapOrientation!.name,
    if (mapShowAirspace != null) 'mapShowAirspace': mapShowAirspace,
    if (mapShowThermals != null) 'mapShowThermals': mapShowThermals,
    if (mapShowTrack != null) 'mapShowTrack': mapShowTrack,
    if (mapShowContours != null) 'mapShowContours': mapShowContours,
    if (mapZoomLevel != null) 'mapZoomLevel': mapZoomLevel,
    if (thermalMapStyle != null) 'thermalMapStyle': thermalMapStyle!.name,
    if (thermalMapShowCore != null) 'thermalMapShowCore': thermalMapShowCore,
    if (thermalMapHistorySeconds != null)
      'thermalMapHistorySeconds': thermalMapHistorySeconds,
    if (mapTrackHistoryMinutes != null)
      'mapTrackHistoryMinutes': mapTrackHistoryMinutes,
    if (mapTrackShowOlderTail != null)
      'mapTrackShowOlderTail': mapTrackShowOlderTail,
    if (mapControlTarget != null) 'mapControlTarget': mapControlTarget,
    if (mapBuiltInControls != null)
      'mapBuiltInControls': mapBuiltInControls!.name,
    if (mapThermalSeason != null) 'mapThermalSeason': mapThermalSeason!.name,
    if (mapThermalTimeOfDay != null)
      'mapThermalTimeOfDay': mapThermalTimeOfDay!.name,
    if (mapThermalOpacity != null) 'mapThermalOpacity': mapThermalOpacity,
  };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WidgetPlacementModel &&
        other.id == id &&
        other.type == type &&
        other.x == x &&
        other.y == y &&
        other.w == w &&
        other.h == h &&
        other.numericStyle == numericStyle &&
        other.windStyle == windStyle &&
        other.varioStyle == varioStyle &&
        other.altitudeChartStyle == altitudeChartStyle &&
        other.mapStyle == mapStyle &&
        other.mapOrientation == mapOrientation &&
        other.mapShowAirspace == mapShowAirspace &&
        other.mapShowThermals == mapShowThermals &&
        other.mapShowTrack == mapShowTrack &&
        other.mapShowContours == mapShowContours &&
        other.mapZoomLevel == mapZoomLevel &&
        other.thermalMapStyle == thermalMapStyle &&
        other.thermalMapShowCore == thermalMapShowCore &&
        other.thermalMapHistorySeconds == thermalMapHistorySeconds &&
        other.mapTrackHistoryMinutes == mapTrackHistoryMinutes &&
        other.mapTrackShowOlderTail == mapTrackShowOlderTail &&
        other.mapControlTarget == mapControlTarget &&
        other.mapBuiltInControls == mapBuiltInControls &&
        other.mapThermalSeason == mapThermalSeason &&
        other.mapThermalTimeOfDay == mapThermalTimeOfDay &&
        other.mapThermalOpacity == mapThermalOpacity;
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    type,
    x,
    y,
    w,
    h,
    numericStyle,
    windStyle,
    varioStyle,
    altitudeChartStyle,
    mapStyle,
    mapOrientation,
    mapShowAirspace,
    mapShowThermals,
    mapShowTrack,
    mapShowContours,
    mapZoomLevel,
    thermalMapStyle,
    thermalMapShowCore,
    thermalMapHistorySeconds,
    mapTrackHistoryMinutes,
    mapTrackShowOlderTail,
    mapControlTarget,
    mapBuiltInControls,
    mapThermalSeason,
    mapThermalTimeOfDay,
    mapThermalOpacity,
  ]);

  @override
  String toString() => 'WidgetPlacementModel($id ${type.name} $x,$y ${w}x$h)';

  factory WidgetPlacementModel.fromJson(Map<String, dynamic> json) {
    NumericWidgetStyle? numStyle;
    if (json['numericStyle'] is String) {
      try {
        numStyle = NumericWidgetStyle.values.byName(
          json['numericStyle'] as String,
        );
      } catch (_) {}
    }

    WindWidgetStyle? wStyle;
    if (json['windStyle'] is String) {
      try {
        wStyle = WindWidgetStyle.values.byName(json['windStyle'] as String);
      } catch (_) {}
    }

    LiftSinkBarStyle? vStyle;
    if (json['varioStyle'] is String) {
      try {
        vStyle = LiftSinkBarStyle.values.byName(json['varioStyle'] as String);
      } catch (_) {}
    }

    AltitudeChartStyle? altStyle;
    if (json['altitudeChartStyle'] is String) {
      try {
        altStyle = AltitudeChartStyle.values.byName(
          json['altitudeChartStyle'] as String,
        );
      } catch (_) {}
    }

    MapWidgetStyle? mStyle;
    if (json['mapStyle'] is String) {
      try {
        mStyle = MapWidgetStyle.values.byName(json['mapStyle'] as String);
      } catch (_) {}
    }

    MapOrientation? mOrientation;
    if (json['mapOrientation'] is String) {
      try {
        mOrientation = MapOrientation.values.byName(
          json['mapOrientation'] as String,
        );
      } catch (_) {}
    }

    ThermalMapStyle? tStyle;
    if (json['thermalMapStyle'] is String) {
      try {
        tStyle = ThermalMapStyle.values.byName(
          json['thermalMapStyle'] as String,
        );
      } catch (_) {}
    }

    MapBuiltInControls? builtIn;
    if (json['mapBuiltInControls'] is String) {
      try {
        builtIn = MapBuiltInControls.values.byName(
          json['mapBuiltInControls'] as String,
        );
      } catch (_) {}
    }

    ThermalSeason? thermalSeason;
    if (json['mapThermalSeason'] is String) {
      try {
        thermalSeason = ThermalSeason.values.byName(
          json['mapThermalSeason'] as String,
        );
      } catch (_) {}
    }

    ThermalTimeOfDay? thermalTime;
    if (json['mapThermalTimeOfDay'] is String) {
      try {
        thermalTime = ThermalTimeOfDay.values.byName(
          json['mapThermalTimeOfDay'] as String,
        );
      } catch (_) {}
    }

    final type = widgetTypeFromName(json['type']);
    if (type == null) {
      throw FormatException('Unknown widget type: ${json['type']}');
    }

    return WidgetPlacementModel(
      id: json['id'] as String,
      type: type,
      x: json['x'] as int,
      y: json['y'] as int,
      w: json['w'] as int,
      h: json['h'] as int,
      numericStyle: numStyle,
      windStyle: wStyle,
      varioStyle: vStyle,
      altitudeChartStyle: altStyle,
      mapStyle: mStyle,
      mapOrientation: mOrientation,
      mapShowAirspace: json['mapShowAirspace'] as bool?,
      mapShowThermals: json['mapShowThermals'] as bool?,
      mapShowTrack: json['mapShowTrack'] as bool?,
      mapShowContours: json['mapShowContours'] as bool?,
      mapZoomLevel: (json['mapZoomLevel'] as num?)?.toDouble(),
      thermalMapStyle: tStyle,
      thermalMapShowCore: json['thermalMapShowCore'] as bool?,
      thermalMapHistorySeconds: json['thermalMapHistorySeconds'] as int?,
      mapTrackHistoryMinutes: json['mapTrackHistoryMinutes'] as int?,
      mapTrackShowOlderTail: json['mapTrackShowOlderTail'] as bool?,
      mapControlTarget: json['mapControlTarget'] as String?,
      mapBuiltInControls: builtIn,
      mapThermalSeason: thermalSeason,
      mapThermalTimeOfDay: thermalTime,
      mapThermalOpacity: (json['mapThermalOpacity'] as num?)?.toDouble(),
    );
  }
}

/// Which layout variant of a screen is meant.
enum LayoutVariant { tall, wide }

class FlightScreenModel {
  const FlightScreenModel({
    required this.id,
    required this.name,
    this.layoutStrategy = LayoutStrategyStyle.sidebarDashboard,
    this.autoSwitchTrigger = ScreenAutoSwitchTrigger.manualOnly,
    this.gridResolution = GridSpec.columns,
    required this.widgets,
    this.wideWidgets,
  });

  final String id;
  final String name;
  final LayoutStrategyStyle layoutStrategy;
  final ScreenAutoSwitchTrigger autoSwitchTrigger;
  final int gridResolution;

  /// Tall layout (required). Used for canvases with width <= height and as
  /// stretched fallback for wide canvases without a wide variant.
  final List<WidgetPlacementModel> widgets;

  /// Optional wide layout for canvases with width > height.
  final List<WidgetPlacementModel>? wideWidgets;

  bool get hasWideVariant => wideWidgets != null;

  /// Widgets of [variant]; the wide variant falls back to the tall layout.
  List<WidgetPlacementModel> widgetsFor(LayoutVariant variant) =>
      variant == LayoutVariant.wide ? (wideWidgets ?? widgets) : widgets;

  /// Returns a copy with [variant] replaced by [list].
  FlightScreenModel withVariantWidgets(
    LayoutVariant variant,
    List<WidgetPlacementModel> list,
  ) {
    return variant == LayoutVariant.wide
        ? copyWith(wideWidgets: list)
        : copyWith(widgets: list);
  }

  FlightScreenModel copyWith({
    String? id,
    String? name,
    LayoutStrategyStyle? layoutStrategy,
    ScreenAutoSwitchTrigger? autoSwitchTrigger,
    int? gridResolution,
    List<WidgetPlacementModel>? widgets,
    List<WidgetPlacementModel>? wideWidgets,
    bool clearWideWidgets = false,
  }) {
    return FlightScreenModel(
      id: id ?? this.id,
      name: name ?? this.name,
      layoutStrategy: layoutStrategy ?? this.layoutStrategy,
      autoSwitchTrigger: autoSwitchTrigger ?? this.autoSwitchTrigger,
      gridResolution: gridResolution ?? this.gridResolution,
      widgets: widgets ?? this.widgets,
      wideWidgets: clearWideWidgets ? null : (wideWidgets ?? this.wideWidgets),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'layoutStrategy': layoutStrategy.name,
    'autoSwitchTrigger': autoSwitchTrigger.name,
    'gridResolution': gridResolution,
    'widgets': widgets.map((w) => w.toJson()).toList(),
    if (wideWidgets != null)
      'wideWidgets': wideWidgets!.map((w) => w.toJson()).toList(),
  };

  /// Parses a stored screen, migrating legacy 4- and 8-column layouts to the
  /// 16x32 grid and clamping out-of-range placements. Unknown widget types are
  /// skipped instead of failing the whole screen.
  factory FlightScreenModel.fromJson(Map<String, dynamic> json) {
    LayoutStrategyStyle strategy = LayoutStrategyStyle.sidebarDashboard;
    if (json['layoutStrategy'] is String) {
      try {
        strategy = LayoutStrategyStyle.values.byName(
          json['layoutStrategy'] as String,
        );
      } catch (_) {}
    }

    ScreenAutoSwitchTrigger trigger = ScreenAutoSwitchTrigger.manualOnly;
    if (json['autoSwitchTrigger'] is String) {
      try {
        trigger = ScreenAutoSwitchTrigger.values.byName(
          json['autoSwitchTrigger'] as String,
        );
      } catch (_) {}
    }

    final resolution = LayoutMigrator.storedResolution(json);
    final tall = _parseWidgets(json['widgets'], resolution);
    final rawWide = json['wideWidgets'];
    // Wide variants only exist from the 16-column schema onwards.
    final wide = rawWide is List && resolution >= GridSpec.columns
        ? _parseWidgets(rawWide, resolution)
        : null;

    return FlightScreenModel(
      id: json['id'] as String,
      name: json['name'] as String,
      layoutStrategy: strategy,
      autoSwitchTrigger: trigger,
      gridResolution: GridSpec.columns,
      widgets: tall,
      wideWidgets: wide,
    );
  }

  static List<WidgetPlacementModel> _parseWidgets(Object? raw, int resolution) {
    if (raw is! List) return const [];
    final migrated = LayoutMigrator.migrateWidgets(raw, resolution);
    final result = <WidgetPlacementModel>[];
    for (final w in migrated) {
      try {
        result.add(WidgetPlacementModel.fromJson(w));
      } catch (_) {
        // Skip malformed widgets; keep the rest of the screen usable.
      }
    }
    return result;
  }
}

class UIConfig {
  const UIConfig({
    this.navBarStyle = NavBarStyle.translucentDrawer,
    this.thermalingStyle = ThermalingStyle.assistantDisplay,
    this.settingsStyle = SettingsStyle.categorizedList,
    this.screens = const [],
    this.activeScreenId = 'normal_flight',
    this.schemaVersion = GridSpec.schemaVersion,
    this.thermalAutoPrefetch = true,
  });

  /// Whether KK7 thermal tiles are prefetched automatically for downloaded
  /// map regions (manual per-region prefetch stays available when false).
  final bool thermalAutoPrefetch;

  /// Persisted schema version (see [GridSpec.schemaVersion]).
  final int schemaVersion;

  final NavBarStyle navBarStyle;
  final ThermalingStyle thermalingStyle;
  final SettingsStyle settingsStyle;
  final List<FlightScreenModel> screens;
  final String activeScreenId;

  /// The active screen, falling back to the first screen (or the default
  /// normal flight screen when no screens exist).
  FlightScreenModel get activeScreen {
    for (final s in screens) {
      if (s.id == activeScreenId) return s;
    }
    return screens.isNotEmpty
        ? screens.first
        : UIConfig.defaultConfig().screens.first;
  }

  /// Reads the stored schema version of a raw config JSON (1 when absent and
  /// screens lack a grid resolution, 2 for 8-column screens).
  static int storedSchemaVersion(Map<String, dynamic> json) {
    final v = json['schemaVersion'];
    if (v is int) return v;
    final screens = json['screens'];
    if (screens is List && screens.isNotEmpty && screens.first is Map) {
      final res = (screens.first as Map)['gridResolution'];
      if (res is int && res >= 8) return 2;
    }
    return 1;
  }

  static UIConfig defaultConfig() {
    return const UIConfig(
      navBarStyle: NavBarStyle.translucentDrawer,
      thermalingStyle: ThermalingStyle.assistantDisplay,
      settingsStyle: SettingsStyle.categorizedList,
      activeScreenId: 'normal_flight',
      screens: [
        FlightScreenModel(
          id: 'normal_flight',
          name: 'Normal Flight Screen',
          layoutStrategy: LayoutStrategyStyle.sidebarDashboard,
          autoSwitchTrigger: ScreenAutoSwitchTrigger.manualOnly,
          widgets: [
            WidgetPlacementModel(
              id: 'w_map',
              type: WidgetType.map,
              x: 0,
              y: 0,
              w: 16,
              h: 32,
              mapStyle: MapWidgetStyle.topoContours,
            ),
            WidgetPlacementModel(
              id: 'w1',
              type: WidgetType.altitude,
              x: 0,
              y: 0,
              w: 4,
              h: 8,
              numericStyle: NumericWidgetStyle.minimalistText,
            ),
            WidgetPlacementModel(
              id: 'w2',
              type: WidgetType.speed,
              x: 0,
              y: 8,
              w: 4,
              h: 8,
              numericStyle: NumericWidgetStyle.minimalistText,
            ),
            WidgetPlacementModel(
              id: 'w3',
              type: WidgetType.varioBar,
              x: 0,
              y: 16,
              w: 4,
              h: 16,
              varioStyle: LiftSinkBarStyle.verticalEdgeBar,
            ),
            WidgetPlacementModel(
              id: 'w4',
              type: WidgetType.windDirection,
              x: 12,
              y: 0,
              w: 4,
              h: 8,
              windStyle: WindWidgetStyle.relativeArrow,
            ),
          ],
        ),
        FlightScreenModel(
          id: 'map_screen',
          name: 'Alpine Map Screen',
          layoutStrategy: LayoutStrategyStyle.freeformHud,
          autoSwitchTrigger: ScreenAutoSwitchTrigger.manualOnly,
          widgets: [
            WidgetPlacementModel(
              id: 'wm_map',
              type: WidgetType.map,
              x: 0,
              y: 0,
              w: 16,
              h: 32,
              mapStyle: MapWidgetStyle.topoContours,
            ),
            WidgetPlacementModel(
              id: 'wm_vario',
              type: WidgetType.varioBar,
              x: 0,
              y: 0,
              w: 4,
              h: 32,
              varioStyle: LiftSinkBarStyle.verticalEdgeBar,
            ),
            WidgetPlacementModel(
              id: 'wm_alt',
              type: WidgetType.altitude,
              x: 4,
              y: 0,
              w: 12,
              h: 8,
              numericStyle: NumericWidgetStyle.minimalistText,
            ),
            WidgetPlacementModel(
              id: 'wm_zoom',
              type: WidgetType.mapZoomRocker,
              x: 13,
              y: 17,
              w: 3,
              h: 6,
            ),
            WidgetPlacementModel(
              id: 'wm_recenter',
              type: WidgetType.mapRecenter,
              x: 13,
              y: 24,
              w: 3,
              h: 3,
            ),
          ],
        ),
        FlightScreenModel(
          id: 'thermaling',
          name: 'Thermaling Screen',
          layoutStrategy: LayoutStrategyStyle.sidebarDashboard,
          autoSwitchTrigger: ScreenAutoSwitchTrigger.onThermalCircling,
          widgets: [
            WidgetPlacementModel(
              id: 'tw_map',
              type: WidgetType.thermalMap,
              x: 0,
              y: 0,
              w: 16,
              h: 32,
              thermalMapStyle: ThermalMapStyle.xctrackBubbles,
            ),
            WidgetPlacementModel(
              id: 'tw1',
              type: WidgetType.varioBar,
              x: 0,
              y: 0,
              w: 4,
              h: 32,
              varioStyle: LiftSinkBarStyle.verticalEdgeBar,
            ),
            WidgetPlacementModel(
              id: 'tw2',
              type: WidgetType.windDirection,
              x: 4,
              y: 0,
              w: 12,
              h: 24,
              windStyle: WindWidgetStyle.relativeArrow,
            ),
            WidgetPlacementModel(
              id: 'tw3',
              type: WidgetType.altitude,
              x: 4,
              y: 24,
              w: 12,
              h: 8,
              numericStyle: NumericWidgetStyle.minimalistText,
            ),
          ],
        ),
      ],
    );
  }

  UIConfig copyWith({
    NavBarStyle? navBarStyle,
    ThermalingStyle? thermalingStyle,
    SettingsStyle? settingsStyle,
    List<FlightScreenModel>? screens,
    String? activeScreenId,
    bool? thermalAutoPrefetch,
  }) {
    return UIConfig(
      navBarStyle: navBarStyle ?? this.navBarStyle,
      thermalingStyle: thermalingStyle ?? this.thermalingStyle,
      settingsStyle: settingsStyle ?? this.settingsStyle,
      screens: screens ?? this.screens,
      activeScreenId: activeScreenId ?? this.activeScreenId,
      thermalAutoPrefetch: thermalAutoPrefetch ?? this.thermalAutoPrefetch,
    );
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': GridSpec.schemaVersion,
    'navBarStyle': navBarStyle.name,
    'thermalingStyle': thermalingStyle.name,
    'settingsStyle': settingsStyle.name,
    'activeScreenId': activeScreenId,
    'thermalAutoPrefetch': thermalAutoPrefetch,
    'screens': screens.map((s) => s.toJson()).toList(),
  };

  factory UIConfig.fromJson(Map<String, dynamic> json) {
    NavBarStyle nav = NavBarStyle.translucentDrawer;
    if (json['navBarStyle'] is String) {
      try {
        nav = NavBarStyle.values.byName(json['navBarStyle'] as String);
      } catch (_) {}
    }

    ThermalingStyle therm = ThermalingStyle.assistantDisplay;
    if (json['thermalingStyle'] is String) {
      try {
        therm = ThermalingStyle.values.byName(
          json['thermalingStyle'] as String,
        );
      } catch (_) {}
    }

    SettingsStyle sett = SettingsStyle.categorizedList;
    if (json['settingsStyle'] is String) {
      try {
        sett = SettingsStyle.values.byName(json['settingsStyle'] as String);
      } catch (_) {}
    }

    return UIConfig(
      navBarStyle: nav,
      thermalingStyle: therm,
      settingsStyle: sett,
      activeScreenId: json['activeScreenId'] as String? ?? 'normal_flight',
      thermalAutoPrefetch: json['thermalAutoPrefetch'] as bool? ?? true,
      screens: json['screens'] != null
          ? (json['screens'] as List<dynamic>)
                .map(
                  (s) => FlightScreenModel.fromJson(s as Map<String, dynamic>),
                )
                .toList()
          : defaultConfig().screens,
    );
  }

  String encodeJson() => jsonEncode(toJson());

  factory UIConfig.decodeJson(String raw) =>
      UIConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}
