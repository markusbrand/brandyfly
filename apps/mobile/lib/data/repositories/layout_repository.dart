import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../domain/models/ui_config.dart';
import '../services/ui_persistence_service.dart';

/// Outcome of loading the stored UI configuration.
enum LayoutLoadOutcome { defaults, loaded, migrated, recoveredFromCorruption }

/// Single source of truth for flight screen layouts.
///
/// Owns loading (with schema migration and backup), the in-memory config and
/// persistence. View models never touch storage directly.
class LayoutRepository extends ChangeNotifier {
  LayoutRepository({
    UIConfig? initialConfig,
    this._persistence,
  }) : _config = initialConfig ?? UIConfig.defaultConfig();

  /// Loads the stored configuration from [persistence].
  ///
  /// * Legacy (schema < 3) payloads are migrated to the 16x32 grid; the
  ///   original payload is kept in a backup slot.
  /// * Corrupted payloads are backed up (slot 0) and defaults are used.
  factory LayoutRepository.load(UIPersistenceService persistence) {
    final raw = persistence.readRaw();
    if (raw == null || raw.isEmpty) {
      return LayoutRepository(persistence: persistence)
        .._loadOutcome = LayoutLoadOutcome.defaults;
    }
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final storedVersion = UIConfig.storedSchemaVersion(json);
      final config = UIPersistenceService.ensureDefaultScreens(
        UIConfig.fromJson(json),
      );
      final repo = LayoutRepository(
        initialConfig: config,
        persistence: persistence,
      );
      if (storedVersion < GridSpec.schemaVersion) {
        repo._loadOutcome = LayoutLoadOutcome.migrated;
        unawaited(
          persistence
              .writeBackup(storedVersion, raw)
              .then((_) => repo._persist(), onError: repo._reportSaveError),
        );
      } else {
        repo._loadOutcome = LayoutLoadOutcome.loaded;
      }
      return repo;
    } catch (error) {
      debugPrint('LayoutRepository: stored UI config unreadable ($error)');
      unawaited(
        persistence.writeBackup(0, raw).catchError((Object _) => false),
      );
      return LayoutRepository(persistence: persistence)
        .._loadOutcome = LayoutLoadOutcome.recoveredFromCorruption;
    }
  }

  UIConfig _config;
  final UIPersistenceService? _persistence;
  LayoutLoadOutcome _loadOutcome = LayoutLoadOutcome.defaults;
  final ValueNotifier<Object?> _lastSaveError = ValueNotifier<Object?>(null);

  UIConfig get config => _config;
  LayoutLoadOutcome get loadOutcome => _loadOutcome;

  /// Last persistence failure (null after a successful save).
  ValueListenable<Object?> get lastSaveError => _lastSaveError;

  /// Replaces the configuration, notifies listeners and persists.
  /// Identical configurations are ignored.
  void replace(UIConfig next) {
    if (identical(next, _config)) return;
    _config = next;
    notifyListeners();
    _persist();
  }

  /// Applies [update] to the screen with [screenId].
  void updateScreen(
    String screenId,
    FlightScreenModel Function(FlightScreenModel screen) update,
  ) {
    var changed = false;
    final screens = [
      for (final s in _config.screens)
        if (s.id == screenId)
          () {
            final u = update(s);
            if (!identical(u, s)) changed = true;
            return u;
          }()
        else
          s,
    ];
    if (!changed) return;
    replace(_config.copyWith(screens: screens));
  }

  Future<void> _persist() async {
    final persistence = _persistence;
    if (persistence == null) return;
    try {
      final ok = await persistence.saveConfig(_config);
      if (!ok && persistence.isAvailable) {
        _reportSaveError(StateError('UI config write rejected by storage'));
      } else {
        _lastSaveError.value = null;
      }
    } catch (error) {
      _reportSaveError(error);
    }
  }

  void _reportSaveError(Object error, [StackTrace? _]) {
    debugPrint('LayoutRepository: failed to persist UI config ($error)');
    _lastSaveError.value = error;
  }

  @override
  void dispose() {
    _lastSaveError.dispose();
    super.dispose();
  }
}
