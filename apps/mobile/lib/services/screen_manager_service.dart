import 'package:flutter/foundation.dart';

import '../data/repositories/layout_repository.dart';
import '../data/services/ui_persistence_service.dart';
import '../domain/models/ui_config.dart';
import '../domain/models/widget_catalog.dart';
import '../ui/features/layout_editor/view_models/edit_mode_view_model.dart';

/// App-shell facade over the layout repository and edit mode view model.
///
/// Keeps the historical public API used by the navigation bar, settings and
/// tests, while layout rules live in the domain layer, persistence in
/// [LayoutRepository] and edit state in [EditModeViewModel]. Also owns shell
/// overlay flags (nav bar, settings, flights screen, replay).
class ScreenManagerService extends ChangeNotifier {
  ScreenManagerService({
    UIConfig? initialConfig,
    UIPersistenceService? persistenceService,
    LayoutRepository? repository,
  }) : _repository =
           repository ??
           LayoutRepository(
             initialConfig: initialConfig,
             persistence: persistenceService,
           ),
       _ownsRepository = repository == null {
    _editMode = EditModeViewModel(_repository);
    _editMode.addListener(notifyListeners);
  }

  final LayoutRepository _repository;
  final bool _ownsRepository;
  late final EditModeViewModel _editMode;

  bool _isNavBarVisible = false;
  bool _isSettingsVisible = false;
  bool _isFlightsScreenVisible = false;
  bool _isReplayActive = false;

  LayoutRepository get layoutRepository => _repository;
  EditModeViewModel get editMode => _editMode;

  UIConfig get config => _repository.config;
  bool get isEditMode => _editMode.isEditMode;
  bool get isNavBarVisible => _isNavBarVisible;
  bool get isSettingsVisible => _isSettingsVisible;
  bool get isFlightsScreenVisible => _isFlightsScreenVisible;
  bool get isReplayActive => _isReplayActive;
  String? get selectedWidgetId => _editMode.selectedWidgetId;

  FlightScreenModel get activeScreen => _repository.config.activeScreen;

  void selectWidget(String? id) => _editMode.select(id);

  void toggleNavBar([bool? visible]) {
    _isNavBarVisible = visible ?? !_isNavBarVisible;
    notifyListeners();
  }

  void toggleEditMode([bool? enabled]) {
    final next = enabled ?? !_editMode.isEditMode;
    final navChanged = next && _isNavBarVisible;
    if (navChanged) _isNavBarVisible = false;
    if (_editMode.isEditMode != next) {
      _editMode.setEditMode(next); // notifies through the edit view model
    } else if (navChanged) {
      notifyListeners();
    }
  }

  void toggleSettingsPanel([bool? visible]) {
    _isSettingsVisible = visible ?? !_isSettingsVisible;
    if (_isSettingsVisible) {
      _isNavBarVisible = false;
      _isFlightsScreenVisible = false;
    }
    notifyListeners();
  }

  void toggleFlightsScreen([bool? visible]) {
    _isFlightsScreenVisible = visible ?? !_isFlightsScreenVisible;
    if (_isFlightsScreenVisible) {
      _isNavBarVisible = false;
      _isSettingsVisible = false;
    }
    notifyListeners();
  }

  void toggleReplayMode([bool? active]) {
    _isReplayActive = active ?? !_isReplayActive;
    if (_isReplayActive) {
      _isFlightsScreenVisible = false;
    }
    notifyListeners();
  }

  void setActiveScreen(String screenId) {
    if (config.activeScreenId == screenId) return;
    _editMode.batch(() {
      _editMode.clearSelectionSilently();
      _repository.replace(config.copyWith(activeScreenId: screenId));
    });
  }

  void setNavBarStyle(NavBarStyle style) =>
      _repository.replace(config.copyWith(navBarStyle: style));

  void setThermalingStyle(ThermalingStyle style) =>
      _repository.replace(config.copyWith(thermalingStyle: style));

  void setSettingsStyle(SettingsStyle style) =>
      _repository.replace(config.copyWith(settingsStyle: style));

  void setThermalAutoPrefetch(bool enabled) =>
      _repository.replace(config.copyWith(thermalAutoPrefetch: enabled));

  void addScreen(
    String name, {
    LayoutStrategyStyle layoutStrategy = LayoutStrategyStyle.sidebarDashboard,
    ScreenAutoSwitchTrigger autoSwitchTrigger =
        ScreenAutoSwitchTrigger.manualOnly,
  }) {
    final newId = 'screen_${DateTime.now().microsecondsSinceEpoch}';
    final newScreen = FlightScreenModel(
      id: newId,
      name: name,
      layoutStrategy: layoutStrategy,
      autoSwitchTrigger: autoSwitchTrigger,
      widgets: const [],
    );
    _editMode.batch(() {
      _editMode.clearSelectionSilently();
      _repository.replace(
        config.copyWith(
          screens: [...config.screens, newScreen],
          activeScreenId: newId,
        ),
      );
    });
  }

  void removeScreen(String screenId) {
    if (config.screens.length <= 1) return; // Keep at least one screen
    if (!config.screens.any((s) => s.id == screenId)) return;

    final updatedScreens = config.screens
        .where((s) => s.id != screenId)
        .toList();
    var nextActive = config.activeScreenId;
    final removingActive = config.activeScreenId == screenId;
    if (removingActive) nextActive = updatedScreens.first.id;

    _editMode.batch(() {
      if (removingActive) _editMode.clearSelectionSilently();
      _repository.replace(
        config.copyWith(screens: updatedScreens, activeScreenId: nextActive),
      );
    });
  }

  void renameScreen(String screenId, String newName) =>
      _repository.updateScreen(screenId, (s) => s.copyWith(name: newName));

  void setScreenLayoutStrategy(String screenId, LayoutStrategyStyle strategy) =>
      _repository.updateScreen(
        screenId,
        (s) => s.copyWith(layoutStrategy: strategy),
      );

  void setScreenAutoSwitchTrigger(
    String screenId,
    ScreenAutoSwitchTrigger trigger,
  ) => _repository.updateScreen(
    screenId,
    (s) => s.copyWith(autoSwitchTrigger: trigger),
  );

  void updateScreen(FlightScreenModel updated) =>
      _repository.updateScreen(updated.id, (_) => updated);

  // Widget operations act on the edited variant of the active screen.

  void updateWidgetPlacement(WidgetPlacementModel placement) =>
      _editMode.updatePlacement(placement);

  void updateWidgetPosition(String widgetId, int x, int y) {
    final current = _find(widgetId);
    if (current == null) return;
    _editMode.updatePlacement(current.copyWith(x: x, y: y));
  }

  void updateWidgetSize(String widgetId, int w, int h) {
    final current = _find(widgetId);
    if (current == null) return;
    _editMode.updatePlacement(current.copyWith(w: w, h: h));
  }

  void moveWidget(String widgetId, int dx, int dy) =>
      _editMode.move(widgetId, dx, dy);

  void resizeWidget(String widgetId, int dw, int dh) =>
      _editMode.resize(widgetId, dw, dh);

  void applySizePreset(String widgetId, SizePreset preset) =>
      _editMode.applyPreset(widgetId, preset);

  void bringToFront(String widgetId) => _editMode.bringToFront(widgetId);
  void bringForward(String widgetId) => _editMode.bringForward(widgetId);
  void sendBackward(String widgetId) => _editMode.sendBackward(widgetId);
  void sendToBack(String widgetId) => _editMode.sendToBack(widgetId);

  /// Adds a widget to the edited variant of the active screen; returns its id.
  String addWidget(WidgetType type) => _editMode.addWidget(type);

  void removeWidget(String widgetId) => _editMode.removeWidget(widgetId);

  WidgetPlacementModel? _find(String id) {
    for (final w in _editMode.editedWidgets) {
      if (w.id == id) return w;
    }
    return null;
  }

  @override
  void dispose() {
    _editMode.removeListener(notifyListeners);
    _editMode.dispose();
    if (_ownsRepository) _repository.dispose();
    super.dispose();
  }
}
