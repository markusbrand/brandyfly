import 'package:shared_preferences/shared_preferences.dart';
import '../models/ui_config.dart';

class UIPersistenceService {
  static const String _keyUIConfig = 'brandyfly_ui_config_v1';

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

  UIConfig loadConfig() {
    if (_prefs == null) {
      return UIConfig.defaultConfig();
    }
    final rawJson = _prefs.getString(_keyUIConfig);
    if (rawJson == null || rawJson.isEmpty) {
      return UIConfig.defaultConfig();
    }
    try {
      return UIConfig.decodeJson(rawJson);
    } catch (_) {
      return UIConfig.defaultConfig();
    }
  }

  Future<bool> saveConfig(UIConfig config) async {
    if (_prefs == null) {
      return false;
    }
    final rawJson = config.encodeJson();
    return _prefs.setString(_keyUIConfig, rawJson);
  }
}
