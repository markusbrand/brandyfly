import 'package:flutter/material.dart';
import '../../models/flight_settings.dart';
import '../../models/ui_config.dart';
import '../../services/flight_tracking_service.dart';
import '../../services/screen_manager_service.dart';
import '../../services/xcontest_upload_service.dart';

class UISettingsPanel extends StatefulWidget {
  const UISettingsPanel({
    super.key,
    required this.screenManager,
    this.trackingService,
    this.uploadService,
  });

  final ScreenManagerService screenManager;
  final FlightTrackingService? trackingService;
  final XContestUploadService? uploadService;

  @override
  State<UISettingsPanel> createState() => _UISettingsPanelState();
}

class _UISettingsPanelState extends State<UISettingsPanel> {
  ScreenManagerService get screenManager => widget.screenManager;
  late TextEditingController _userController;
  late TextEditingController _passController;

  @override
  void initState() {
    super.initState();
    final settings = widget.trackingService?.settings ?? const FlightSettings();
    _userController = TextEditingController(text: settings.xcontestUsername);
    _passController = TextEditingController(text: settings.xcontestPassword);
  }

  @override
  void dispose() {
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cfg = widget.screenManager.config;
    final style = cfg.settingsStyle;

    switch (style) {
      case SettingsStyle.categorizedList:
        return _buildCategorizedList(context, cfg);
      case SettingsStyle.modalOverlay:
        return _buildModalOverlay(context, cfg);
      case SettingsStyle.cardDashboard:
        return _buildCardDashboard(context, cfg);
    }
  }

  // Option 2: Full-Screen Categorized List (Default)
  Widget _buildCategorizedList(BuildContext context, UIConfig cfg) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        title: const Text('Application Settings'),
        backgroundColor: Colors.grey.shade900,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Close',
            onPressed: () => widget.screenManager.toggleSettingsPanel(false),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ..._buildShellAndNavSection(cfg),
          const Divider(color: Colors.white24, height: 32),
          ..._buildScreenManagementSection(cfg),
          const Divider(color: Colors.white24, height: 32),
          ..._buildFlightTrackingSection(),
          const Divider(color: Colors.white24, height: 32),
          ..._buildXContestSection(),
        ],
      ),
    );
  }

  List<Widget> _buildShellAndNavSection(UIConfig cfg) {
    return [
      _buildCategoryHeader('Shell & Navigation Preferences'),
      _buildEnumSelector<NavBarStyle>(
        title: 'Navigation Bar Style (REQ-UI-003)',
        currentValue: cfg.navBarStyle,
        values: NavBarStyle.values,
        labels: {
          NavBarStyle.translucentDrawer:
              'Option 1: Full-Width Translucent Drawer',
          NavBarStyle.floatingPill: 'Option 2: Floating Action Pill',
          NavBarStyle.cornerMenu: 'Option 3: Corner Menu Button',
        },
        onChanged: (val) => screenManager.setNavBarStyle(val),
      ),
      _buildEnumSelector<SettingsStyle>(
        title: 'Settings Screen Layout',
        currentValue: cfg.settingsStyle,
        values: SettingsStyle.values,
        labels: {
          SettingsStyle.modalOverlay: 'Option 1: Modal Overlay Dialog',
          SettingsStyle.categorizedList:
              'Option 2: Full-Screen Categorized List',
          SettingsStyle.cardDashboard: 'Option 3: Card-Based Dashboard',
        },
        onChanged: (val) => screenManager.setSettingsStyle(val),
      ),
      _buildEnumSelector<ThermalingStyle>(
        title: 'Thermaling Mode Display',
        currentValue: cfg.thermalingStyle,
        values: ThermalingStyle.values,
        labels: {
          ThermalingStyle.zoomedRadar: 'Option 1: Zoomed Radar',
          ThermalingStyle.focusMode: 'Option 2: Focus Mode',
          ThermalingStyle.assistantDisplay: 'Option 3: Assistant Display',
        },
        onChanged: (val) => screenManager.setThermalingStyle(val),
      ),
    ];
  }

  List<Widget> _buildScreenManagementSection(UIConfig cfg) {
    final activeScreen = screenManager.activeScreen;

    return [
      _buildCategoryHeader('Flight Screen Management'),
      Card(
        color: Colors.grey.shade900,
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Active Screen & Layout Strategy',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Active Screen:', style: TextStyle(color: Colors.white70)),
                  DropdownButton<String>(
                    value: activeScreen.id,
                    dropdownColor: Colors.blueGrey.shade900,
                    underline: const SizedBox(),
                    style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold),
                    items: cfg.screens.map((s) {
                      return DropdownMenuItem<String>(
                        value: s.id,
                        child: Text(s.name),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        screenManager.setActiveScreen(val);
                        setState(() {});
                      }
                    },
                  ),
                ],
              ),
              const Divider(color: Colors.white12),
              _buildEnumSelector<LayoutStrategyStyle>(
                title: 'Screen Layout Strategy (${activeScreen.name})',
                currentValue: activeScreen.layoutStrategy,
                values: LayoutStrategyStyle.values,
                labels: {
                  LayoutStrategyStyle.freeformHud: 'Option 1: Freeform HUD',
                  LayoutStrategyStyle.snapToGrid: 'Option 2: Snap-to-Grid',
                  LayoutStrategyStyle.sidebarDashboard: 'Option 3: Sidebar Dashboard',
                },
                onChanged: (val) {
                  screenManager.setScreenLayoutStrategy(activeScreen.id, val);
                  setState(() {});
                },
              ),
              const SizedBox(height: 4),
              _buildEnumSelector<ScreenAutoSwitchTrigger>(
                title: 'Automatic Screen Switch Trigger',
                currentValue: activeScreen.autoSwitchTrigger,
                values: ScreenAutoSwitchTrigger.values,
                labels: {
                  ScreenAutoSwitchTrigger.manualOnly: 'Manual Switch Only',
                  ScreenAutoSwitchTrigger.onThermalCircling: 'Auto: When Circling in Thermal',
                  ScreenAutoSwitchTrigger.onGlideStraight: 'Auto: When Gliding Straight',
                },
                onChanged: (val) {
                  screenManager.setScreenAutoSwitchTrigger(activeScreen.id, val);
                  setState(() {});
                },
              ),
            ],
          ),
        ),
      ),
    ];
  }

  // Option 1: Modal Overlay Dialog
  Widget _buildModalOverlay(BuildContext context, UIConfig cfg) {
    return Dialog(
      backgroundColor: Colors.grey.shade900,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Quick Global Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  tooltip: 'Close',
                  onPressed: () => screenManager.toggleSettingsPanel(false),
                ),
              ],
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildEnumSelector<NavBarStyle>(
                      title: 'Navigation Bar Style',
                      currentValue: cfg.navBarStyle,
                      values: NavBarStyle.values,
                      labels: {
                        NavBarStyle.translucentDrawer:
                            'Option 1: Translucent Drawer',
                        NavBarStyle.floatingPill: 'Option 2: Floating Pill',
                        NavBarStyle.cornerMenu: 'Option 3: Corner Menu',
                      },
                      onChanged: (val) => screenManager.setNavBarStyle(val),
                    ),
                    _buildEnumSelector<SettingsStyle>(
                      title: 'Settings Layout',
                      currentValue: cfg.settingsStyle,
                      values: SettingsStyle.values,
                      labels: {
                        SettingsStyle.modalOverlay: 'Option 1: Modal Dialog',
                        SettingsStyle.categorizedList: 'Option 2: Full List',
                        SettingsStyle.cardDashboard: 'Option 3: Dashboard',
                      },
                      onChanged: (val) => screenManager.setSettingsStyle(val),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Option 3: Card-Based Dashboard
  Widget _buildCardDashboard(BuildContext context, UIConfig cfg) {
    final activeScreen = screenManager.activeScreen;

    return Scaffold(
      backgroundColor: Colors.blueGrey.shade900,
      appBar: AppBar(
        title: const Text('Settings Dashboard'),
        backgroundColor: Colors.blueGrey.shade900,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Close',
            onPressed: () => screenManager.toggleSettingsPanel(false),
          ),
        ],
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16),
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        children: [
          _buildCardItem<NavBarStyle>(
            'Nav Bar',
            cfg.navBarStyle,
            NavBarStyle.values,
            (v) => screenManager.setNavBarStyle(v),
          ),
          _buildCardItem<SettingsStyle>(
            'Settings Style',
            cfg.settingsStyle,
            SettingsStyle.values,
            (v) => screenManager.setSettingsStyle(v),
          ),
          _buildCardItem<LayoutStrategyStyle>(
            'Layout Strategy',
            activeScreen.layoutStrategy,
            LayoutStrategyStyle.values,
            (v) => screenManager.setScreenLayoutStrategy(activeScreen.id, v),
          ),
          _buildCardItem<ScreenAutoSwitchTrigger>(
            'Auto-Switch Trigger',
            activeScreen.autoSwitchTrigger,
            ScreenAutoSwitchTrigger.values,
            (v) => screenManager.setScreenAutoSwitchTrigger(activeScreen.id, v),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Colors.cyanAccent,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildEnumSelector<T extends Enum>({
    required String title,
    required T currentValue,
    required List<T> values,
    required Map<T, String> labels,
    required ValueChanged<T> onChanged,
  }) {
    return Card(
      color: Colors.grey.shade900,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: values.map((val) {
                final isSelected = val == currentValue;
                return ChoiceChip(
                  label: Text(labels[val] ?? val.name),
                  selected: isSelected,
                  selectedColor: Colors.cyan.shade700,
                  backgroundColor: Colors.black45,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontSize: 12,
                  ),
                  onSelected: (sel) {
                    if (sel) onChanged(val);
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardItem<T extends Enum>(
    String title,
    T currentValue,
    List<T> values,
    ValueChanged<T> onChanged,
  ) {
    return Card(
      color: Colors.blueGrey.shade900,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButton<T>(
              value: currentValue,
              dropdownColor: Colors.blueGrey.shade900,
              items: values.map((v) {
                return DropdownMenuItem<T>(
                  value: v,
                  child: Text(
                    v.name,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) onChanged(val);
              },
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFlightTrackingSection() {
    final settings = widget.trackingService?.settings ?? const FlightSettings();
    return [
      _buildCategoryHeader('Flight Tracking & Sensor Fusion'),
      Card(
        color: Colors.blueGrey.shade900,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Takeoff Speed Threshold (km/h)',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              Slider(
                value: settings.takeoffSpeedThresholdKmh,
                min: 5.0,
                max: 25.0,
                divisions: 20,
                label: '${settings.takeoffSpeedThresholdKmh.toStringAsFixed(1)} km/h',
                onChanged: (val) {
                  widget.trackingService?.updateSettings(
                    settings.copyWith(takeoffSpeedThresholdKmh: val),
                  );
                  setState(() {});
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'Takeoff Vario Trigger (|m/s|)',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              Slider(
                value: settings.takeoffVarioThresholdMs,
                min: 0.2,
                max: 2.0,
                divisions: 18,
                label: '${settings.takeoffVarioThresholdMs.toStringAsFixed(1)} m/s',
                onChanged: (val) {
                  widget.trackingService?.updateSettings(
                    settings.copyWith(takeoffVarioThresholdMs: val),
                  );
                  setState(() {});
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'Landing Settling Duration (seconds)',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              Slider(
                value: settings.landingSettlingDurationSeconds.toDouble(),
                min: 5.0,
                max: 60.0,
                divisions: 11,
                label: '${settings.landingSettlingDurationSeconds}s',
                onChanged: (val) {
                  widget.trackingService?.updateSettings(
                    settings.copyWith(landingSettlingDurationSeconds: val.round()),
                  );
                  setState(() {});
                },
              ),
            ],
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildXContestSection() {
    final settings = widget.trackingService?.settings ?? const FlightSettings();
    return [
      _buildCategoryHeader('XContest.org Integration'),
      Card(
        color: Colors.blueGrey.shade900,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                title: const Text(
                  'Auto-upload on landing',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Automatically upload finalized flights to XContest.org upon landing detection',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
                value: settings.autoUploadToXContest,
                activeThumbColor: Colors.cyanAccent,
                onChanged: (val) {
                  final newSettings = settings.copyWith(autoUploadToXContest: val);
                  widget.trackingService?.updateSettings(newSettings);
                  widget.uploadService?.updateSettings(newSettings);
                  setState(() {});
                },
              ),
              const Divider(color: Colors.white12),
              TextField(
                controller: _userController,
                textInputAction: TextInputAction.next,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'XContest Username',
                  labelStyle: TextStyle(color: Colors.white70),
                  prefixIcon: Icon(Icons.person, color: Colors.white60),
                ),
                onChanged: (val) {
                  final newSettings = settings.copyWith(xcontestUsername: val);
                  widget.trackingService?.updateSettings(newSettings);
                  widget.uploadService?.updateSettings(newSettings);
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _passController,
                obscureText: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'XContest Password / API Key',
                  labelStyle: TextStyle(color: Colors.white70),
                  prefixIcon: Icon(Icons.lock, color: Colors.white60),
                ),
                onChanged: (val) {
                  final newSettings = settings.copyWith(xcontestPassword: val);
                  widget.trackingService?.updateSettings(newSettings);
                  widget.uploadService?.updateSettings(newSettings);
                },
              ),
            ],
          ),
        ),
      ),
    ];
  }
}
