import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:brandyfly/services/ui_persistence_service.dart';
import 'package:brandyfly/models/ui_config.dart';

void main() {
  group('UIPersistenceService', () {
    const String keyUIConfig = 'brandyfly_ui_config_v1';

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    group('init', () {
      test('initializes with SharedPreferences', () async {
        final service = await UIPersistenceService.init();
        expect(service, isNotNull);
      });
    });

    group('loadConfig', () {
      test('returns default config if SharedPreferences is null', () {
        final service = UIPersistenceService(null);
        final config = service.loadConfig();

        expect(config.activeScreenId, UIConfig.defaultConfig().activeScreenId);
      });

      test('returns default config if nothing is stored in SharedPreferences', () async {
        final service = await UIPersistenceService.init();
        final config = service.loadConfig();

        expect(config.activeScreenId, UIConfig.defaultConfig().activeScreenId);
      });

      test('returns default config if stored data is invalid JSON', () async {
        SharedPreferences.setMockInitialValues({
          keyUIConfig: 'invalid_json'
        });

        final service = await UIPersistenceService.init();
        final config = service.loadConfig();

        expect(config.activeScreenId, UIConfig.defaultConfig().activeScreenId);
      });

      test('returns decoded config if valid JSON is stored', () async {
        final customConfig = UIConfig.defaultConfig().copyWith(activeScreenId: 'custom_screen');
        SharedPreferences.setMockInitialValues({
          keyUIConfig: customConfig.encodeJson()
        });

        final service = await UIPersistenceService.init();
        final config = service.loadConfig();

        expect(config.activeScreenId, 'custom_screen');
      });
    });

    group('saveConfig', () {
      test('returns false if SharedPreferences is null', () async {
        final service = UIPersistenceService(null);
        final config = UIConfig.defaultConfig();

        final result = await service.saveConfig(config);

        expect(result, isFalse);
      });

      test('saves correctly and returns true if SharedPreferences is initialized', () async {
        final service = await UIPersistenceService.init();
        final config = UIConfig.defaultConfig().copyWith(activeScreenId: 'saved_screen');

        final result = await service.saveConfig(config);

        expect(result, isTrue);

        // Verify it was actually saved
        final prefs = await SharedPreferences.getInstance();
        final savedJson = prefs.getString(keyUIConfig);
        expect(savedJson, isNotNull);

        final loadedConfig = UIConfig.decodeJson(savedJson!);
        expect(loadedConfig.activeScreenId, 'saved_screen');
      });
    });
  });
}
