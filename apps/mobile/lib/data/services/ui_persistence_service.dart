import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/ui_config.dart';

/// Thin storage wrapper around SharedPreferences for the UI configuration.
///
/// Holds no business logic beyond raw read/write; schema migration and backup
/// policy live in the layout repository.
class UIPersistenceService {
  static const String _keyUIConfig = 'brandyfly_ui_config_v1';
  static const String _keyBackupPrefix = 'brandyfly_ui_config_backup_v';

  final SharedPreferences? _prefs;

  UIPersistenceService([this._prefs]);

  static Future<UIPersistenceService> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return UIPersistenceService(prefs);
    } catch (_) {
      return UIPersistenceService(null);
    }
  }

  bool get isAvailable => _prefs != null;

  /// Raw stored configuration JSON, or null.
  String? readRaw() => _prefs?.getString(_keyUIConfig);

  /// Writes raw configuration JSON. Returns false when storage is unavailable.
  Future<bool> writeRaw(String raw) async {
    final prefs = _prefs;
    if (prefs == null) return false;
    return prefs.setString(_keyUIConfig, raw);
  }

  /// Backup of the payload stored before migrating from [schemaVersion].
  String? readBackup(int schemaVersion) =>
      _prefs?.getString('$_keyBackupPrefix$schemaVersion');

  Future<bool> writeBackup(int schemaVersion, String raw) async {
    final prefs = _prefs;
    if (prefs == null) return false;
    return prefs.setString('$_keyBackupPrefix$schemaVersion', raw);
  }

  /// Decodes the stored configuration (migrating legacy layouts) or returns
  /// defaults when nothing valid is stored.
  UIConfig loadConfig() {
    final rawJson = readRaw();
    if (rawJson == null || rawJson.isEmpty) {
      return UIConfig.defaultConfig();
    }
    try {
      final config = UIConfig.decodeJson(rawJson);
      return ensureDefaultScreens(config);
    } catch (_) {
      return UIConfig.defaultConfig();
    }
  }

  /// Guarantees the built-in normal flight screen has a map and the map
  /// screen exists.
  static UIConfig ensureDefaultScreens(UIConfig config) {
    final defaults = UIConfig.defaultConfig().screens;
    final updatedScreens = config.screens.map((screen) {
      if (screen.id == 'normal_flight') {
        final hasMap = screen.widgets.any((w) => w.type == WidgetType.map);
        if (!hasMap) {
          return defaults.firstWhere((s) => s.id == 'normal_flight');
        }
      }
      return screen;
    }).toList();

    final hasMapScreen = updatedScreens.any((s) => s.id == 'map_screen');
    if (!hasMapScreen) {
      updatedScreens.add(defaults.firstWhere((s) => s.id == 'map_screen'));
    }
    return config.copyWith(screens: updatedScreens);
  }

  Future<bool> saveConfig(UIConfig config) => writeRaw(config.encodeJson());
}
