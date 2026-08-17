import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:brandyfly/services/ui_persistence_service.dart';
import 'package:brandyfly/models/ui_config.dart';
import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UIPersistenceService', () {
    const String _keyUIConfig = 'brandyfly_ui_config_v1';

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('init() returns service with prefs on success', () async {
      final service = await UIPersistenceService.init();
      // Test that it can save, which requires _prefs to not be null.
      final result = await service.saveConfig(UIConfig.defaultConfig());
      expect(result, isTrue);
    });

    // Currently we can't easily force SharedPreferences.getInstance() to fail in Dart,
    // so we test the null fallback behaviors directly by passing null via the constructor.
    test('handles null SharedPreferences gracefully (fallback behavior)', () async {
      final service = UIPersistenceService(null);

      // loadConfig should return defaultConfig when _prefs is null
      final config = service.loadConfig();
      expect(config.screens.length, equals(UIConfig.defaultConfig().screens.length));

      // saveConfig should return false when _prefs is null
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
        _keyUIConfig: '{ invalid json }'
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
        _keyUIConfig: modifiedConfig.encodeJson()
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
