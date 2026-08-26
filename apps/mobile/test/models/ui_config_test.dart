import 'dart:convert';
import 'package:brandyfly/models/ui_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WidgetPlacementModel Serialization & Fallbacks', () {
    test('effective getters return fallback defaults when styling fields are null', () {
      const model = WidgetPlacementModel(
        id: 'w_test',
        type: WidgetType.altitude,
        x: 0,
        y: 0,
        w: 2,
        h: 1,
      );

      expect(model.numericStyle, isNull);
      expect(model.effectiveNumericStyle, NumericWidgetStyle.minimalistText);
      expect(model.effectiveWindStyle, WindWidgetStyle.relativeArrow);
      expect(model.effectiveVarioStyle, LiftSinkBarStyle.verticalEdgeBar);
      expect(model.effectiveAltitudeChartStyle, AltitudeChartStyle.minimalSparkline);
      expect(model.effectiveMapStyle, MapWidgetStyle.topoContours);
      expect(model.effectiveMapOrientation, MapOrientation.trackUp);
      expect(model.effectiveMapShowAirspace, isTrue);
      expect(model.effectiveMapShowThermals, isTrue);
      expect(model.effectiveMapShowTrack, isTrue);
      expect(model.effectiveMapShowContours, isTrue);
      expect(model.mapZoomLevel, isNull);
      expect(model.effectiveMapZoomLevel, 13.5);
      expect(model.effectiveThermalMapStyle, ThermalMapStyle.xctrackBubbles);
      expect(model.effectiveThermalMapShowCore, isTrue);
      expect(model.effectiveThermalMapHistorySeconds, 90);
    });

    test('roundtrip serialization preserves thermal map style and configuration', () {
      const model = WidgetPlacementModel(
        id: 'w_thermal_custom',
        type: WidgetType.thermalMap,
        x: 0,
        y: 0,
        w: 4,
        h: 4,
        thermalMapStyle: ThermalMapStyle.burnairCore,
        thermalMapShowCore: false,
        thermalMapHistorySeconds: 120,
      );

      final json = model.toJson();
      final restored = WidgetPlacementModel.fromJson(json);

      expect(restored.id, 'w_thermal_custom');
      expect(restored.type, WidgetType.thermalMap);
      expect(restored.thermalMapStyle, ThermalMapStyle.burnairCore);
      expect(restored.effectiveThermalMapStyle, ThermalMapStyle.burnairCore);
      expect(restored.thermalMapShowCore, isFalse);
      expect(restored.effectiveThermalMapShowCore, isFalse);
      expect(restored.thermalMapHistorySeconds, 120);
      expect(restored.effectiveThermalMapHistorySeconds, 120);
    });

    test('roundtrip serialization preserves widget-specific styles and layers', () {
      const model = WidgetPlacementModel(
        id: 'w_map_custom',
        type: WidgetType.map,
        x: 0,
        y: 0,
        w: 4,
        h: 4,
        numericStyle: NumericWidgetStyle.retroDigital,
        windStyle: WindWidgetStyle.windsockIndicator,
        varioStyle: LiftSinkBarStyle.screenEdgeGlow,
        altitudeChartStyle: AltitudeChartStyle.detailedGrid,
        mapStyle: MapWidgetStyle.thermalHeatmap,
        mapOrientation: MapOrientation.headingUp,
        mapShowAirspace: false,
        mapShowThermals: true,
        mapShowTrack: false,
        mapShowContours: true,
        mapZoomLevel: 15.0,
      );

      final json = model.toJson();
      final restored = WidgetPlacementModel.fromJson(json);

      expect(restored.id, 'w_map_custom');
      expect(restored.type, WidgetType.map);
      expect(restored.numericStyle, NumericWidgetStyle.retroDigital);
      expect(restored.effectiveNumericStyle, NumericWidgetStyle.retroDigital);
      expect(restored.windStyle, WindWidgetStyle.windsockIndicator);
      expect(restored.varioStyle, LiftSinkBarStyle.screenEdgeGlow);
      expect(restored.altitudeChartStyle, AltitudeChartStyle.detailedGrid);
      expect(restored.mapStyle, MapWidgetStyle.thermalHeatmap);
      expect(restored.mapOrientation, MapOrientation.headingUp);
      expect(restored.mapShowAirspace, isFalse);
      expect(restored.mapShowThermals, isTrue);
      expect(restored.mapShowTrack, isFalse);
      expect(restored.mapShowContours, isTrue);
      expect(restored.mapZoomLevel, 15.0);
      expect(restored.effectiveMapZoomLevel, 15.0);
    });

    test('fromJson gracefully handles unknown enum strings or missing fields', () {
      final json = <String, dynamic>{
        'id': 'w_legacy',
        'type': 'altitude',
        'x': 1,
        'y': 2,
        'w': 2,
        'h': 1,
        'numericStyle': 'invalid_unknown_style',
        'mapStyle': 'unknown_map_style',
      };

      final restored = WidgetPlacementModel.fromJson(json);
      expect(restored.id, 'w_legacy');
      expect(restored.type, WidgetType.altitude);
      expect(restored.numericStyle, isNull);
      expect(restored.effectiveNumericStyle, NumericWidgetStyle.minimalistText);
      expect(restored.mapStyle, isNull);
      expect(restored.effectiveMapStyle, MapWidgetStyle.topoContours);
      expect(restored.mapZoomLevel, isNull);
      expect(restored.effectiveMapZoomLevel, 13.5);
    });

    test('copyWith updates individual properties accurately', () {
      const model = WidgetPlacementModel(
        id: 'w_test',
        type: WidgetType.speed,
        x: 0,
        y: 0,
        w: 2,
        h: 1,
      );

      final updated = model.copyWith(
        x: 2,
        w: 1,
        numericStyle: NumericWidgetStyle.circularGauge,
        mapZoomLevel: 16.5,
      );

      expect(updated.id, 'w_test');
      expect(updated.type, WidgetType.speed);
      expect(updated.x, 2);
      expect(updated.w, 1);
      expect(updated.numericStyle, NumericWidgetStyle.circularGauge);
      expect(updated.effectiveNumericStyle, NumericWidgetStyle.circularGauge);
      expect(updated.mapZoomLevel, 16.5);
      expect(updated.effectiveMapZoomLevel, 16.5);
    });
  });

  group('FlightScreenModel Serialization & Screen Triggers', () {
    test('roundtrip serialization preserves layoutStrategy and autoSwitchTrigger', () {
      const screen = FlightScreenModel(
        id: 'screen_thermal',
        name: 'Thermal Radar',
        layoutStrategy: LayoutStrategyStyle.freeformHud,
        autoSwitchTrigger: ScreenAutoSwitchTrigger.onThermalCircling,
        widgets: [
          WidgetPlacementModel(
            id: 'tw_vario',
            type: WidgetType.varioBar,
            x: 0,
            y: 0,
            w: 1,
            h: 3,
            varioStyle: LiftSinkBarStyle.analogDial,
          ),
        ],
      );

      final json = screen.toJson();
      final restored = FlightScreenModel.fromJson(json);

      expect(restored.id, 'screen_thermal');
      expect(restored.name, 'Thermal Radar');
      expect(restored.layoutStrategy, LayoutStrategyStyle.freeformHud);
      expect(restored.autoSwitchTrigger, ScreenAutoSwitchTrigger.onThermalCircling);
      expect(restored.widgets.length, 1);
      expect(restored.widgets.first.varioStyle, LiftSinkBarStyle.analogDial);
    });

    test('fromJson handles legacy screens without autoSwitchTrigger or layoutStrategy', () {
      final json = <String, dynamic>{
        'id': 'legacy_screen',
        'name': 'Legacy',
        'widgets': <dynamic>[],
      };

      final restored = FlightScreenModel.fromJson(json);
      expect(restored.id, 'legacy_screen');
      expect(restored.layoutStrategy, LayoutStrategyStyle.sidebarDashboard);
      expect(restored.autoSwitchTrigger, ScreenAutoSwitchTrigger.manualOnly);
      expect(restored.widgets, isEmpty);
    });
  });

  group('UIConfig Serialization & Backward Compatibility', () {
    test('encodes and decodes UIConfig roundtrip', () {
      final config = UIConfig.defaultConfig().copyWith(
        navBarStyle: NavBarStyle.cornerMenu,
        settingsStyle: SettingsStyle.cardDashboard,
      );

      final jsonString = config.encodeJson();
      final restored = UIConfig.decodeJson(jsonString);

      expect(restored.navBarStyle, NavBarStyle.cornerMenu);
      expect(restored.settingsStyle, SettingsStyle.cardDashboard);
      expect(restored.screens.length, config.screens.length);
      expect(restored.activeScreenId, config.activeScreenId);
    });

    test('backward compatibility: decodes legacy UIConfig JSON containing global widget styling fields without error', () {
      final legacyJson = {
        'navBarStyle': 'floatingPill',
        'layoutStrategyStyle': 'snapToGrid',
        'numericWidgetStyle': 'highContrastBox',
        'windWidgetStyle': 'miniCompassRose',
        'liftSinkBarStyle': 'analogDial',
        'altitudeChartStyle': 'filledAreaGraph',
        'mapWidgetStyle': 'satelliteTerrain',
        'mapOrientation': 'northUp',
        'mapShowAirspace': false,
        'activeScreenId': 'normal_flight',
        'screens': [
          {
            'id': 'normal_flight',
            'name': 'Normal Flight Screen',
            'layoutStrategy': 'snapToGrid',
            'widgets': [
              {
                'id': 'w1',
                'type': 'altitude',
                'x': 0,
                'y': 0,
                'w': 2,
                'h': 1,
              }
            ]
          }
        ]
      };

      final jsonString = jsonEncode(legacyJson);
      final restored = UIConfig.decodeJson(jsonString);

      expect(restored.navBarStyle, NavBarStyle.floatingPill);
      expect(restored.screens.length, 1);
      expect(restored.screens.first.widgets.first.type, WidgetType.altitude);
      expect(restored.screens.first.widgets.first.effectiveNumericStyle, NumericWidgetStyle.minimalistText);
    });
  });
}
