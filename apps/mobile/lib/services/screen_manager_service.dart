import 'package:flutter/material.dart';
import '../models/ui_config.dart';
import 'ui_persistence_service.dart';

class ScreenManagerService extends ChangeNotifier {
  ScreenManagerService({
    UIConfig? initialConfig,
    UIPersistenceService? persistenceService,
  }) : _config = initialConfig ?? UIConfig.defaultConfig(),
       _persistence = persistenceService;

  UIConfig _config;
  final UIPersistenceService? _persistence;
  bool _isEditMode = false;
  bool _isNavBarVisible = false;
  bool _isSettingsVisible = false;
  bool _isFlightsScreenVisible = false;
  bool _isReplayActive = false;

  UIConfig get config => _config;
  bool get isEditMode => _isEditMode;
  bool get isNavBarVisible => _isNavBarVisible;
  bool get isSettingsVisible => _isSettingsVisible;
  bool get isFlightsScreenVisible => _isFlightsScreenVisible;
  bool get isReplayActive => _isReplayActive;

  FlightScreenModel get activeScreen {
    final found = _config.screens.firstWhere(
      (s) => s.id == _config.activeScreenId,
      orElse: () => _config.screens.isNotEmpty
          ? _config.screens.first
          : UIConfig.defaultConfig().screens.first,
    );
    return found;
  }

  void toggleNavBar([bool? visible]) {
    _isNavBarVisible = visible ?? !_isNavBarVisible;
    notifyListeners();
  }

  void toggleEditMode([bool? enabled]) {
    _isEditMode = enabled ?? !_isEditMode;
    if (_isEditMode) {
      _isNavBarVisible = false;
    }
    notifyListeners();
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
    if (_config.activeScreenId == screenId) return;
    _config = _config.copyWith(activeScreenId: screenId);
    _saveAndNotify();
  }

  void setNavBarStyle(NavBarStyle style) {
    _config = _config.copyWith(navBarStyle: style);
    _saveAndNotify();
  }

  void setThermalingStyle(ThermalingStyle style) {
    _config = _config.copyWith(thermalingStyle: style);
    _saveAndNotify();
  }

  void setSettingsStyle(SettingsStyle style) {
    _config = _config.copyWith(settingsStyle: style);
    _saveAndNotify();
  }

  void addScreen(
    String name, {
    LayoutStrategyStyle layoutStrategy = LayoutStrategyStyle.sidebarDashboard,
    ScreenAutoSwitchTrigger autoSwitchTrigger = ScreenAutoSwitchTrigger.manualOnly,
  }) {
    final newId = 'screen_${DateTime.now().millisecondsSinceEpoch}';
    final newScreen = FlightScreenModel(
      id: newId,
      name: name,
      layoutStrategy: layoutStrategy,
      autoSwitchTrigger: autoSwitchTrigger,
      widgets: const [],
    );
    final updatedScreens = [..._config.screens, newScreen];
    _config = _config.copyWith(screens: updatedScreens, activeScreenId: newId);
    _saveAndNotify();
  }

  void removeScreen(String screenId) {
    if (_config.screens.length <= 1) return; // Keep at least one screen
    final updatedScreens = _config.screens
        .where((s) => s.id != screenId)
        .toList();
    final nextActive = updatedScreens.first.id;
    _config = _config.copyWith(
      screens: updatedScreens,
      activeScreenId: nextActive,
    );
    _saveAndNotify();
  }

  void renameScreen(String screenId, String newName) {
    final updatedScreens = _config.screens.map((s) {
      return s.id == screenId ? s.copyWith(name: newName) : s;
    }).toList();
    _config = _config.copyWith(screens: updatedScreens);
    _saveAndNotify();
  }

  void setScreenLayoutStrategy(String screenId, LayoutStrategyStyle strategy) {
    final updatedScreens = _config.screens.map((s) {
      return s.id == screenId ? s.copyWith(layoutStrategy: strategy) : s;
    }).toList();
    _config = _config.copyWith(screens: updatedScreens);
    _saveAndNotify();
  }

  void setScreenAutoSwitchTrigger(String screenId, ScreenAutoSwitchTrigger trigger) {
    final updatedScreens = _config.screens.map((s) {
      return s.id == screenId ? s.copyWith(autoSwitchTrigger: trigger) : s;
    }).toList();
    _config = _config.copyWith(screens: updatedScreens);
    _saveAndNotify();
  }

  void updateScreen(FlightScreenModel updated) {
    final updatedScreens = _config.screens.map((s) {
      return s.id == updated.id ? updated : s;
    }).toList();
    _config = _config.copyWith(screens: updatedScreens);
    _saveAndNotify();
  }

  void updateWidgetPlacement(WidgetPlacementModel placement) {
    final currentActive = activeScreen;
    final clampedW = placement.w.clamp(1, 8);
    final clampedH = placement.h.clamp(1, 16);
    final clampedX = placement.x.clamp(0, (8 - clampedW).clamp(0, 7));
    final clampedY = placement.y.clamp(0, 20);

    final sanitized = placement.copyWith(
      x: clampedX,
      y: clampedY,
      w: clampedW,
      h: clampedH,
    );

    final updatedWidgets = currentActive.widgets.map((w) {
      return w.id == sanitized.id ? sanitized : w;
    }).toList();

    _updateActiveScreen(currentActive.copyWith(widgets: updatedWidgets));
  }

  void updateWidgetPosition(String widgetId, int x, int y) {
    final currentActive = activeScreen;
    final index = currentActive.widgets.indexWhere((w) => w.id == widgetId);
    if (index == -1) return;
    final current = currentActive.widgets[index];
    updateWidgetPlacement(current.copyWith(x: x, y: y));
  }

  void updateWidgetSize(String widgetId, int w, int h) {
    final currentActive = activeScreen;
    final index = currentActive.widgets.indexWhere((w) => w.id == widgetId);
    if (index == -1) return;
    final current = currentActive.widgets[index];
    updateWidgetPlacement(current.copyWith(w: w, h: h));
  }

  void moveWidget(String widgetId, int dx, int dy) {
    final currentActive = activeScreen;
    final index = currentActive.widgets.indexWhere((w) => w.id == widgetId);
    if (index == -1) return;
    final current = currentActive.widgets[index];
    updateWidgetPlacement(
      current.copyWith(
        x: current.x + dx,
        y: current.y + dy,
      ),
    );
  }

  void resizeWidget(String widgetId, int dw, int dh) {
    final currentActive = activeScreen;
    final index = currentActive.widgets.indexWhere((w) => w.id == widgetId);
    if (index == -1) return;
    final current = currentActive.widgets[index];
    updateWidgetPlacement(
      current.copyWith(
        w: current.w + dw,
        h: current.h + dh,
      ),
    );
  }

  void addWidget(WidgetType type) {
    final currentActive = activeScreen;
    final newId = 'w_${DateTime.now().millisecondsSinceEpoch}';
    final isMapLike = type == WidgetType.map || type == WidgetType.thermalMap;
    final newPlacement = WidgetPlacementModel(
      id: newId,
      type: type,
      x: 0,
      y: 0,
      w: isMapLike ? 8 : 4,
      h: isMapLike ? 8 : 2,
      numericStyle: NumericWidgetStyle.minimalistText,
      windStyle: WindWidgetStyle.relativeArrow,
      varioStyle: LiftSinkBarStyle.verticalEdgeBar,
      altitudeChartStyle: AltitudeChartStyle.minimalSparkline,
      mapStyle: MapWidgetStyle.topoContours,
      mapOrientation: MapOrientation.trackUp,
      mapShowAirspace: true,
      mapShowThermals: true,
      mapShowTrack: true,
      mapShowContours: true,
      thermalMapStyle: ThermalMapStyle.xctrackBubbles,
      thermalMapShowCore: true,
      thermalMapHistorySeconds: 90,
    );
    final updatedWidgets = [...currentActive.widgets, newPlacement];
    _updateActiveScreen(currentActive.copyWith(widgets: updatedWidgets));
  }

  void removeWidget(String widgetId) {
    final currentActive = activeScreen;
    final updatedWidgets = currentActive.widgets
        .where((w) => w.id != widgetId)
        .toList();
    _updateActiveScreen(currentActive.copyWith(widgets: updatedWidgets));
  }

  void _updateActiveScreen(FlightScreenModel updated) {
    final updatedScreens = _config.screens.map((s) {
      return s.id == updated.id ? updated : s;
    }).toList();
    _config = _config.copyWith(screens: updatedScreens);
    _saveAndNotify();
  }

  void _saveAndNotify() {
    _persistence?.saveConfig(_config);
    notifyListeners();
  }
}
