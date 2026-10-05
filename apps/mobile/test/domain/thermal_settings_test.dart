import 'package:brandyfly/data/services/ui_persistence_service.dart';
import 'package:brandyfly/domain/models/ui_config.dart';
import 'package:brandyfly/services/screen_manager_service.dart';
import 'package:brandyfly/data/repositories/layout_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Map thermal settings on WidgetPlacementModel', () {
    test('round-trips season, time of day and opacity through JSON', () {
      const model = WidgetPlacementModel(
        id: 'm',
        type: WidgetType.map,
        x: 0,
        y: 0,
        w: 16,
        h: 32,
        mapShowThermals: false,
        mapThermalSeason: ThermalSeason.jul,
        mapThermalTimeOfDay: ThermalTimeOfDay.morning,
        mapThermalOpacity: 0.3,
      );
      final decoded = WidgetPlacementModel.fromJson(model.toJson());
      expect(decoded, model);
      expect(decoded.effectiveMapShowThermals, isFalse);
      expect(decoded.effectiveMapThermalSeason, ThermalSeason.jul);
      expect(decoded.effectiveMapThermalTimeOfDay, ThermalTimeOfDay.morning);
      expect(decoded.effectiveMapThermalOpacity, 0.3);
    });

    test('legacy configs without thermal fields load with defaults', () {
      final legacy = {
        'id': 'm',
        'type': 'map',
        'x': 0,
        'y': 0,
        'w': 16,
        'h': 32,
        'mapStyle': 'topoContours',
      };
      final decoded = WidgetPlacementModel.fromJson(legacy);
      expect(decoded.effectiveMapShowThermals, isTrue);
      expect(decoded.effectiveMapThermalSeason, ThermalSeason.auto);
      expect(decoded.effectiveMapThermalTimeOfDay, ThermalTimeOfDay.auto);
      expect(decoded.effectiveMapThermalOpacity, 0.6);
      expect(decoded.toJson().containsKey('mapThermalSeason'), isFalse);
    });

    test('unknown enum names fall back to defaults and opacity is clamped', () {
      final decoded = WidgetPlacementModel.fromJson({
        'id': 'm',
        'type': 'map',
        'x': 0,
        'y': 0,
        'w': 4,
        'h': 4,
        'mapThermalSeason': 'monsoon',
        'mapThermalTimeOfDay': 'night',
        'mapThermalOpacity': 5,
      });
      expect(decoded.effectiveMapThermalSeason, ThermalSeason.auto);
      expect(decoded.effectiveMapThermalTimeOfDay, ThermalTimeOfDay.auto);
      expect(decoded.effectiveMapThermalOpacity, 1.0);
    });
  });

  group('UIConfig.thermalAutoPrefetch', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('defaults to true, also for legacy JSON', () {
      expect(UIConfig.defaultConfig().thermalAutoPrefetch, isTrue);
      final legacy = UIConfig.fromJson({'activeScreenId': 'normal_flight'});
      expect(legacy.thermalAutoPrefetch, isTrue);
    });

    test('is persisted and survives a reload', () async {
      final persistence = await UIPersistenceService.init();
      final repo = LayoutRepository.load(persistence);
      final manager = ScreenManagerService(repository: repo);
      manager.setThermalAutoPrefetch(false);
      expect(manager.config.thermalAutoPrefetch, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final reloaded = LayoutRepository.load(await UIPersistenceService.init());
      expect(reloaded.config.thermalAutoPrefetch, isFalse);
      manager.dispose();
      repo.dispose();
      reloaded.dispose();
    });

    test('per-widget thermal setting survives restart', () async {
      final persistence = await UIPersistenceService.init();
      final repo = LayoutRepository.load(persistence);
      final manager = ScreenManagerService(repository: repo);
      final map = manager.activeScreen.widgets.firstWhere(
        (w) => w.type == WidgetType.map,
      );
      manager.updateWidgetPlacement(map.copyWith(mapShowThermals: false));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final reloaded = LayoutRepository.load(await UIPersistenceService.init());
      final reloadedMap = reloaded.config.activeScreen.widgets.firstWhere(
        (w) => w.id == map.id,
      );
      expect(reloadedMap.effectiveMapShowThermals, isFalse);
      manager.dispose();
      repo.dispose();
      reloaded.dispose();
    });
  });
}
