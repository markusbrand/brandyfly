import 'dart:convert';

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
  topoContours, // Option 1 (Default)
  minimalVector, // Option 2
  thermalHeatmap, // Option 3
  satelliteTerrain, // Option 4
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
}

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
  });

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
  int get effectiveThermalMapHistorySeconds =>
      thermalMapHistorySeconds ?? 90;

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
  };

  factory WidgetPlacementModel.fromJson(Map<String, dynamic> json) {
    NumericWidgetStyle? numStyle;
    if (json['numericStyle'] is String) {
      try {
        numStyle =
            NumericWidgetStyle.values.byName(json['numericStyle'] as String);
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
        mOrientation =
            MapOrientation.values.byName(json['mapOrientation'] as String);
      } catch (_) {}
    }

    ThermalMapStyle? tStyle;
    if (json['thermalMapStyle'] is String) {
      try {
        tStyle =
            ThermalMapStyle.values.byName(json['thermalMapStyle'] as String);
      } catch (_) {}
    }

    return WidgetPlacementModel(
      id: json['id'] as String,
      type: WidgetType.values.byName(json['type'] as String),
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
    );
  }
}

class FlightScreenModel {
  const FlightScreenModel({
    required this.id,
    required this.name,
    this.layoutStrategy = LayoutStrategyStyle.sidebarDashboard,
    this.autoSwitchTrigger = ScreenAutoSwitchTrigger.manualOnly,
    this.gridResolution = 8,
    required this.widgets,
  });

  final String id;
  final String name;
  final LayoutStrategyStyle layoutStrategy;
  final ScreenAutoSwitchTrigger autoSwitchTrigger;
  final int gridResolution;
  final List<WidgetPlacementModel> widgets;

  FlightScreenModel copyWith({
    String? id,
    String? name,
    LayoutStrategyStyle? layoutStrategy,
    ScreenAutoSwitchTrigger? autoSwitchTrigger,
    int? gridResolution,
    List<WidgetPlacementModel>? widgets,
  }) {
    return FlightScreenModel(
      id: id ?? this.id,
      name: name ?? this.name,
      layoutStrategy: layoutStrategy ?? this.layoutStrategy,
      autoSwitchTrigger: autoSwitchTrigger ?? this.autoSwitchTrigger,
      gridResolution: gridResolution ?? this.gridResolution,
      widgets: widgets ?? this.widgets,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'layoutStrategy': layoutStrategy.name,
    'autoSwitchTrigger': autoSwitchTrigger.name,
    'gridResolution': gridResolution,
    'widgets': widgets.map((w) => w.toJson()).toList(),
  };

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

    final rawWidgets = (json['widgets'] as List<dynamic>? ?? [])
        .map(
          (w) => WidgetPlacementModel.fromJson(w as Map<String, dynamic>),
        )
        .toList();

    final gridRes = json['gridResolution'] as int? ?? 4;
    final migratedWidgets = (gridRes < 8 && rawWidgets.isNotEmpty)
        ? rawWidgets.map((w) => w.copyWith(
            x: w.x * 2,
            y: w.y * 2,
            w: w.w * 2,
            h: w.h * 2,
          )).toList()
        : rawWidgets;

    return FlightScreenModel(
      id: json['id'] as String,
      name: json['name'] as String,
      layoutStrategy: strategy,
      autoSwitchTrigger: trigger,
      gridResolution: 8,
      widgets: migratedWidgets,
    );
  }
}

class UIConfig {
  const UIConfig({
    this.navBarStyle = NavBarStyle.translucentDrawer,
    this.thermalingStyle = ThermalingStyle.assistantDisplay,
    this.settingsStyle = SettingsStyle.categorizedList,
    this.screens = const [],
    this.activeScreenId = 'normal_flight',
  });

  final NavBarStyle navBarStyle;
  final ThermalingStyle thermalingStyle;
  final SettingsStyle settingsStyle;
  final List<FlightScreenModel> screens;
  final String activeScreenId;

  static UIConfig defaultConfig() {
    return UIConfig(
      navBarStyle: NavBarStyle.translucentDrawer,
      thermalingStyle: ThermalingStyle.assistantDisplay,
      settingsStyle: SettingsStyle.categorizedList,
      activeScreenId: 'normal_flight',
      screens: const [
        FlightScreenModel(
          id: 'normal_flight',
          name: 'Normal Flight Screen',
          layoutStrategy: LayoutStrategyStyle.sidebarDashboard,
          autoSwitchTrigger: ScreenAutoSwitchTrigger.manualOnly,
          gridResolution: 8,
          widgets: [
            WidgetPlacementModel(
              id: 'w_map',
              type: WidgetType.map,
              x: 0,
              y: 0,
              w: 8,
              h: 8,
              mapStyle: MapWidgetStyle.topoContours,
            ),
            WidgetPlacementModel(
              id: 'w1',
              type: WidgetType.altitude,
              x: 0,
              y: 0,
              w: 2,
              h: 2,
              numericStyle: NumericWidgetStyle.minimalistText,
            ),
            WidgetPlacementModel(
              id: 'w2',
              type: WidgetType.speed,
              x: 0,
              y: 2,
              w: 2,
              h: 2,
              numericStyle: NumericWidgetStyle.minimalistText,
            ),
            WidgetPlacementModel(
              id: 'w3',
              type: WidgetType.varioBar,
              x: 0,
              y: 4,
              w: 2,
              h: 4,
              varioStyle: LiftSinkBarStyle.verticalEdgeBar,
            ),
            WidgetPlacementModel(
              id: 'w4',
              type: WidgetType.windDirection,
              x: 6,
              y: 0,
              w: 2,
              h: 2,
              windStyle: WindWidgetStyle.relativeArrow,
            ),
          ],
        ),
        FlightScreenModel(
          id: 'map_screen',
          name: 'Alpine Map Screen',
          layoutStrategy: LayoutStrategyStyle.freeformHud,
          autoSwitchTrigger: ScreenAutoSwitchTrigger.manualOnly,
          gridResolution: 8,
          widgets: [
            WidgetPlacementModel(
              id: 'wm_map',
              type: WidgetType.map,
              x: 0,
              y: 0,
              w: 8,
              h: 8,
              mapStyle: MapWidgetStyle.topoContours,
            ),
            WidgetPlacementModel(
              id: 'wm_vario',
              type: WidgetType.varioBar,
              x: 0,
              y: 0,
              w: 2,
              h: 8,
              varioStyle: LiftSinkBarStyle.verticalEdgeBar,
            ),
            WidgetPlacementModel(
              id: 'wm_alt',
              type: WidgetType.altitude,
              x: 2,
              y: 0,
              w: 6,
              h: 2,
              numericStyle: NumericWidgetStyle.minimalistText,
            ),
          ],
        ),
        FlightScreenModel(
          id: 'thermaling',
          name: 'Thermaling Screen',
          layoutStrategy: LayoutStrategyStyle.sidebarDashboard,
          autoSwitchTrigger: ScreenAutoSwitchTrigger.onThermalCircling,
          gridResolution: 8,
          widgets: [
            WidgetPlacementModel(
              id: 'tw_map',
              type: WidgetType.thermalMap,
              x: 0,
              y: 0,
              w: 8,
              h: 8,
              thermalMapStyle: ThermalMapStyle.xctrackBubbles,
            ),
            WidgetPlacementModel(
              id: 'tw1',
              type: WidgetType.varioBar,
              x: 0,
              y: 0,
              w: 2,
              h: 8,
              varioStyle: LiftSinkBarStyle.verticalEdgeBar,
            ),
            WidgetPlacementModel(
              id: 'tw2',
              type: WidgetType.windDirection,
              x: 2,
              y: 0,
              w: 6,
              h: 6,
              windStyle: WindWidgetStyle.relativeArrow,
            ),
            WidgetPlacementModel(
              id: 'tw3',
              type: WidgetType.altitude,
              x: 2,
              y: 6,
              w: 6,
              h: 2,
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
  }) {
    return UIConfig(
      navBarStyle: navBarStyle ?? this.navBarStyle,
      thermalingStyle: thermalingStyle ?? this.thermalingStyle,
      settingsStyle: settingsStyle ?? this.settingsStyle,
      screens: screens ?? this.screens,
      activeScreenId: activeScreenId ?? this.activeScreenId,
    );
  }

  Map<String, dynamic> toJson() => {
    'navBarStyle': navBarStyle.name,
    'thermalingStyle': thermalingStyle.name,
    'settingsStyle': settingsStyle.name,
    'activeScreenId': activeScreenId,
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
        therm =
            ThermalingStyle.values.byName(json['thermalingStyle'] as String);
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
      screens: json['screens'] != null
          ? (json['screens'] as List<dynamic>)
              .map((s) => FlightScreenModel.fromJson(s as Map<String, dynamic>))
              .toList()
          : defaultConfig().screens,
    );
  }

  String encodeJson() => jsonEncode(toJson());

  factory UIConfig.decodeJson(String raw) =>
      UIConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}
