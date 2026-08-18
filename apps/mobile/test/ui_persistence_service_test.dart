import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:brandyfly/services/ui_persistence_service.dart';
import 'package:brandyfly/models/ui_config.dart';

class ThrowingMockSharedPreferencesStore extends SharedPreferencesStorePlatform {
  @override
  Future<bool> clear() async => throw Exception('clear');
  @override
  Future<Map<String, Object>> getAll() async => throw Exception('getAll');
  @override
  Future<bool> remove(String key) async => throw Exception('remove');
  @override
  Future<bool> setValue(String valueType, String key, Object value) async => throw Exception('setValue');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UIPersistenceService', () {
    const String keyUIConfig = 'brandyfly_ui_config_v1';

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('init() returns service with prefs on success', () async {
      final service = await UIPersistenceService.init();
      // Test that it can save, which requires _prefs to not be null.
      final result = await service.saveConfig(UIConfig.defaultConfig());
      expect(result, isTrue);
    });

    test('init() handles SharedPreferences initialization failure gracefully', () async {
      final originalInstance = SharedPreferencesStorePlatform.instance;
      SharedPreferencesStorePlatform.instance = ThrowingMockSharedPreferencesStore();

      final service = await UIPersistenceService.init();

      // Should fall back to null prefs and default config
      final config = service.loadConfig();
      expect(config.screens.length, equals(UIConfig.defaultConfig().screens.length));

      final success = await service.saveConfig(config);
      expect(success, isFalse);

      SharedPreferencesStorePlatform.instance = originalInstance;
    });

    test('handles null SharedPreferences explicitly passed', () async {
      final service = UIPersistenceService(null);

      final config = service.loadConfig();
      expect(config.screens.length, equals(UIConfig.defaultConfig().screens.length));

      final success = await service.saveConfig(config);
      expect(success, isFalse);
    });

    test('loadConfig() returns default config when json is missing', () async {
      final service = await UIPersistenceService.init();
      final config = service.loadConfig();
      expect(config.screens.length, equals(UIConfig.defaultConfig().screens.length));
    });

    test('loadConfig() returns default config when json is invalid', () async {
      SharedPreferences.setMockInitialValues({
        keyUIConfig: '{ invalid json }'
      });
      final service = await UIPersistenceService.init();
      final config = service.loadConfig();
      expect(config.screens.length, equals(UIConfig.defaultConfig().screens.length));
    });

    test('loadConfig() returns parsed config when json is valid', () async {
      final defaultConfig = UIConfig.defaultConfig();
      final modifiedConfig = defaultConfig.copyWith(
        navBarStyle: NavBarStyle.floatingPill
      );

      SharedPreferences.setMockInitialValues({
        keyUIConfig: modifiedConfig.encodeJson()
      });

      final service = await UIPersistenceService.init();
      final config = service.loadConfig();

      expect(config.navBarStyle, equals(NavBarStyle.floatingPill));
    });

    test('saveConfig() stores valid json', () async {
      final service = await UIPersistenceService.init();
      final config = UIConfig.defaultConfig().copyWith(
        navBarStyle: NavBarStyle.cornerMenu
      );

      final success = await service.saveConfig(config);
      expect(success, isTrue);

      final loadedConfig = service.loadConfig();
      expect(loadedConfig.navBarStyle, equals(NavBarStyle.cornerMenu));
    });
  });
}
