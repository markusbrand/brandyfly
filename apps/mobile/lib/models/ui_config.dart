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

enum ThermalingStyle {
  zoomedRadar, // Option 1
  focusMode, // Option 2
  assistantDisplay, // Option 3 (Default)
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
}

class WidgetPlacementModel {
  const WidgetPlacementModel({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  final String id;
  final WidgetType type;
  final int x;
  final int y;
  final int w;
  final int h;

  WidgetPlacementModel copyWith({
    String? id,
    WidgetType? type,
    int? x,
    int? y,
    int? w,
    int? h,
  }) {
    return WidgetPlacementModel(
      id: id ?? this.id,
      type: type ?? this.type,
      x: x ?? this.x,
      y: y ?? this.y,
      w: w ?? this.w,
      h: h ?? this.h,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'x': x,
    'y': y,
    'w': w,
    'h': h,
  };

  factory WidgetPlacementModel.fromJson(Map<String, dynamic> json) =>
      WidgetPlacementModel(
        id: json['id'] as String,
        type: WidgetType.values.byName(json['type'] as String),
        x: json['x'] as int,
        y: json['y'] as int,
        w: json['w'] as int,
        h: json['h'] as int,
      );
}

class FlightScreenModel {
  const FlightScreenModel({
    required this.id,
    required this.name,
    this.layoutStrategy = LayoutStrategyStyle.sidebarDashboard,
    required this.widgets,
  });

  final String id;
  final String name;
  final LayoutStrategyStyle layoutStrategy;
  final List<WidgetPlacementModel> widgets;

  FlightScreenModel copyWith({
    String? id,
    String? name,
    LayoutStrategyStyle? layoutStrategy,
    List<WidgetPlacementModel>? widgets,
  }) {
    return FlightScreenModel(
      id: id ?? this.id,
      name: name ?? this.name,
      layoutStrategy: layoutStrategy ?? this.layoutStrategy,
      widgets: widgets ?? this.widgets,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'layoutStrategy': layoutStrategy.name,
    'widgets': widgets.map((w) => w.toJson()).toList(),
  };

  factory FlightScreenModel.fromJson(Map<String, dynamic> json) =>
      FlightScreenModel(
        id: json['id'] as String,
        name: json['name'] as String,
        layoutStrategy: LayoutStrategyStyle.values.byName(
          json['layoutStrategy'] as String? ?? 'sidebarDashboard',
        ),
        widgets: (json['widgets'] as List<dynamic>)
            .map(
              (w) => WidgetPlacementModel.fromJson(w as Map<String, dynamic>),
            )
            .toList(),
      );
}

class UIConfig {
  const UIConfig({
    this.navBarStyle = NavBarStyle.translucentDrawer,
    this.layoutStrategyStyle = LayoutStrategyStyle.sidebarDashboard,
    this.numericWidgetStyle = NumericWidgetStyle.minimalistText,
    this.windWidgetStyle = WindWidgetStyle.relativeArrow,
    this.liftSinkBarStyle = LiftSinkBarStyle.verticalEdgeBar,
    this.altitudeChartStyle = AltitudeChartStyle.minimalSparkline,
    this.thermalingStyle = ThermalingStyle.assistantDisplay,
    this.settingsStyle = SettingsStyle.categorizedList,
    this.screens = const [],
    this.activeScreenId = 'normal_flight',
  });

  final NavBarStyle navBarStyle;
  final LayoutStrategyStyle layoutStrategyStyle;
  final NumericWidgetStyle numericWidgetStyle;
  final WindWidgetStyle windWidgetStyle;
  final LiftSinkBarStyle liftSinkBarStyle;
  final AltitudeChartStyle altitudeChartStyle;
  final ThermalingStyle thermalingStyle;
  final SettingsStyle settingsStyle;
  final List<FlightScreenModel> screens;
  final String activeScreenId;

  static UIConfig defaultConfig() {
    return UIConfig(
      navBarStyle: NavBarStyle.translucentDrawer,
      layoutStrategyStyle: LayoutStrategyStyle.sidebarDashboard,
      numericWidgetStyle: NumericWidgetStyle.minimalistText,
      windWidgetStyle: WindWidgetStyle.relativeArrow,
      liftSinkBarStyle: LiftSinkBarStyle.verticalEdgeBar,
      altitudeChartStyle: AltitudeChartStyle.minimalSparkline,
      thermalingStyle: ThermalingStyle.assistantDisplay,
      settingsStyle: SettingsStyle.categorizedList,
      activeScreenId: 'normal_flight',
      screens: const [
        FlightScreenModel(
          id: 'normal_flight',
          name: 'Normal Flight Screen',
          layoutStrategy: LayoutStrategyStyle.sidebarDashboard,
          widgets: [
            WidgetPlacementModel(
              id: 'w1',
              type: WidgetType.altitude,
              x: 0,
              y: 0,
              w: 2,
              h: 1,
            ),
            WidgetPlacementModel(
              id: 'w2',
              type: WidgetType.speed,
              x: 2,
              y: 0,
              w: 2,
              h: 1,
            ),
            WidgetPlacementModel(
              id: 'w3',
              type: WidgetType.varioBar,
              x: 0,
              y: 1,
              w: 1,
              h: 3,
            ),
            WidgetPlacementModel(
              id: 'w4',
              type: WidgetType.windDirection,
              x: 1,
              y: 1,
              w: 3,
              h: 2,
            ),
            WidgetPlacementModel(
              id: 'w5',
              type: WidgetType.altitudeChart,
              x: 1,
              y: 3,
              w: 3,
              h: 1,
            ),
          ],
        ),
        FlightScreenModel(
          id: 'thermaling',
          name: 'Thermaling Screen',
          layoutStrategy: LayoutStrategyStyle.sidebarDashboard,
          widgets: [
            WidgetPlacementModel(
              id: 'tw1',
              type: WidgetType.varioBar,
              x: 0,
              y: 0,
              w: 1,
              h: 4,
            ),
            WidgetPlacementModel(
              id: 'tw2',
              type: WidgetType.windDirection,
              x: 1,
              y: 0,
              w: 3,
              h: 3,
            ),
            WidgetPlacementModel(
              id: 'tw3',
              type: WidgetType.altitude,
              x: 1,
              y: 3,
              w: 3,
              h: 1,
            ),
          ],
        ),
      ],
    );
  }

  UIConfig copyWith({
    NavBarStyle? navBarStyle,
    LayoutStrategyStyle? layoutStrategyStyle,
    NumericWidgetStyle? numericWidgetStyle,
    WindWidgetStyle? windWidgetStyle,
    LiftSinkBarStyle? liftSinkBarStyle,
    AltitudeChartStyle? altitudeChartStyle,
    ThermalingStyle? thermalingStyle,
    SettingsStyle? settingsStyle,
    List<FlightScreenModel>? screens,
    String? activeScreenId,
  }) {
    return UIConfig(
      navBarStyle: navBarStyle ?? this.navBarStyle,
      layoutStrategyStyle: layoutStrategyStyle ?? this.layoutStrategyStyle,
      numericWidgetStyle: numericWidgetStyle ?? this.numericWidgetStyle,
      windWidgetStyle: windWidgetStyle ?? this.windWidgetStyle,
      liftSinkBarStyle: liftSinkBarStyle ?? this.liftSinkBarStyle,
      altitudeChartStyle: altitudeChartStyle ?? this.altitudeChartStyle,
      thermalingStyle: thermalingStyle ?? this.thermalingStyle,
      settingsStyle: settingsStyle ?? this.settingsStyle,
      screens: screens ?? this.screens,
      activeScreenId: activeScreenId ?? this.activeScreenId,
    );
  }

  Map<String, dynamic> toJson() => {
    'navBarStyle': navBarStyle.name,
    'layoutStrategyStyle': layoutStrategyStyle.name,
    'numericWidgetStyle': numericWidgetStyle.name,
    'windWidgetStyle': windWidgetStyle.name,
    'liftSinkBarStyle': liftSinkBarStyle.name,
    'altitudeChartStyle': altitudeChartStyle.name,
    'thermalingStyle': thermalingStyle.name,
    'settingsStyle': settingsStyle.name,
    'activeScreenId': activeScreenId,
    'screens': screens.map((s) => s.toJson()).toList(),
  };

  factory UIConfig.fromJson(Map<String, dynamic> json) => UIConfig(
    navBarStyle: NavBarStyle.values.byName(
      json['navBarStyle'] as String? ?? 'translucentDrawer',
    ),
    layoutStrategyStyle: LayoutStrategyStyle.values.byName(
      json['layoutStrategyStyle'] as String? ?? 'sidebarDashboard',
    ),
    numericWidgetStyle: NumericWidgetStyle.values.byName(
      json['numericWidgetStyle'] as String? ?? 'minimalistText',
    ),
    windWidgetStyle: WindWidgetStyle.values.byName(
      json['windWidgetStyle'] as String? ?? 'relativeArrow',
    ),
    liftSinkBarStyle: LiftSinkBarStyle.values.byName(
      json['liftSinkBarStyle'] as String? ?? 'verticalEdgeBar',
    ),
    altitudeChartStyle: AltitudeChartStyle.values.byName(
      json['altitudeChartStyle'] as String? ?? 'minimalSparkline',
    ),
    thermalingStyle: ThermalingStyle.values.byName(
      json['thermalingStyle'] as String? ?? 'assistantDisplay',
    ),
    settingsStyle: SettingsStyle.values.byName(
      json['settingsStyle'] as String? ?? 'categorizedList',
    ),
    activeScreenId: json['activeScreenId'] as String? ?? 'normal_flight',
    screens: json['screens'] != null
        ? (json['screens'] as List<dynamic>)
              .map((s) => FlightScreenModel.fromJson(s as Map<String, dynamic>))
              .toList()
        : defaultConfig().screens,
  );

  String encodeJson() => jsonEncode(toJson());

  factory UIConfig.decodeJson(String raw) =>
      UIConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}
