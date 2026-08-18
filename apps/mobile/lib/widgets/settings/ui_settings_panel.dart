import 'package:flutter/material.dart';
import '../../models/ui_config.dart';
import '../../services/screen_manager_service.dart';

class UISettingsPanel extends StatelessWidget {
  const UISettingsPanel({super.key, required this.screenManager});

  final ScreenManagerService screenManager;

  @override
  Widget build(BuildContext context) {
    final cfg = screenManager.config;
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
        title: const Text('UI Visual Mockup Settings'),
        backgroundColor: Colors.grey.shade900,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Close',
            onPressed: () => screenManager.toggleSettingsPanel(false),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ..._buildNavigationAndLayoutSection(cfg),
          const Divider(color: Colors.white24, height: 32),
          ..._buildFlightInstrumentsSection(cfg),
          const Divider(color: Colors.white24, height: 32),
          ..._buildScreenModesSection(cfg),
        ],
      ),
    );
  }

  List<Widget> _buildNavigationAndLayoutSection(UIConfig cfg) {
    return [
      _buildCategoryHeader('Navigation & Layout'),
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
      _buildEnumSelector<LayoutStrategyStyle>(
        title: 'Flight Screen Layout Strategy (REQ-UI-004)',
        currentValue: cfg.layoutStrategyStyle,
        values: LayoutStrategyStyle.values,
        labels: {
          LayoutStrategyStyle.freeformHud: 'Option 1: Freeform HUD',
          LayoutStrategyStyle.snapToGrid: 'Option 2: Snap-to-Grid',
          LayoutStrategyStyle.sidebarDashboard:
              'Option 3: Sidebar Dashboard',
        },
        onChanged: (val) => screenManager.setLayoutStrategyStyle(val),
      ),
    ];
  }

  List<Widget> _buildFlightInstrumentsSection(UIConfig cfg) {
    return [
      _buildCategoryHeader('Flight Instruments & Widgets'),
      _buildEnumSelector<NumericWidgetStyle>(
        title: 'Numeric / Text Widgets',
        currentValue: cfg.numericWidgetStyle,
        values: NumericWidgetStyle.values,
        labels: {
          NumericWidgetStyle.minimalistText: 'Option 1: Minimalist Text',
          NumericWidgetStyle.highContrastBox: 'Option 2: High-Contrast Box',
          NumericWidgetStyle.circularGauge: 'Option 3: Circular Gauge',
          NumericWidgetStyle.retroDigital: 'Option 4: Retro Digital',
        },
        onChanged: (val) => screenManager.setNumericWidgetStyle(val),
      ),
      _buildEnumSelector<WindWidgetStyle>(
        title: 'Wind Direction Widget',
        currentValue: cfg.windWidgetStyle,
        values: WindWidgetStyle.values,
        labels: {
          WindWidgetStyle.relativeArrow: 'Option 1: Relative Arrow',
          WindWidgetStyle.miniCompassRose: 'Option 2: Mini Compass Rose',
          WindWidgetStyle.windsockIndicator: 'Option 3: Windsock Indicator',
        },
        onChanged: (val) => screenManager.setWindWidgetStyle(val),
      ),
      _buildEnumSelector<LiftSinkBarStyle>(
        title: 'Visual Lift / Sink Bar',
        currentValue: cfg.liftSinkBarStyle,
        values: LiftSinkBarStyle.values,
        labels: {
          LiftSinkBarStyle.verticalEdgeBar: 'Option 1: Vertical Edge Bar',
          LiftSinkBarStyle.analogDial: 'Option 2: Analog Dial',
          LiftSinkBarStyle.screenEdgeGlow: 'Option 3: Screen Edge Glow',
        },
        onChanged: (val) => screenManager.setLiftSinkBarStyle(val),
      ),
      _buildEnumSelector<AltitudeChartStyle>(
        title: 'Altitude Sparkline Chart',
        currentValue: cfg.altitudeChartStyle,
        values: AltitudeChartStyle.values,
        labels: {
          AltitudeChartStyle.minimalSparkline:
              'Option 1: Minimal Sparkline',
          AltitudeChartStyle.filledAreaGraph: 'Option 2: Filled Area Graph',
          AltitudeChartStyle.detailedGrid: 'Option 3: Detailed Grid',
        },
        onChanged: (val) => screenManager.setAltitudeChartStyle(val),
      ),
    ];
  }

  List<Widget> _buildScreenModesSection(UIConfig cfg) {
    return [
      _buildCategoryHeader('Screen Modes & Overlays'),
      _buildEnumSelector<ThermalingStyle>(
        title: 'Thermaling Screen Style',
        currentValue: cfg.thermalingStyle,
        values: ThermalingStyle.values,
        labels: {
          ThermalingStyle.zoomedRadar: 'Option 1: Zoomed Radar',
          ThermalingStyle.focusMode: 'Option 2: Focus Mode',
          ThermalingStyle.assistantDisplay: 'Option 3: Assistant Display',
        },
        onChanged: (val) => screenManager.setThermalingStyle(val),
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
                  'Quick UI Settings',
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
    return Scaffold(
      backgroundColor: Colors.blueGrey.shade900,
      appBar: AppBar(
        title: const Text('UI Options Dashboard'),
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
          _buildCardItem<LayoutStrategyStyle>(
            'Layout Strategy',
            cfg.layoutStrategyStyle,
            LayoutStrategyStyle.values,
            (v) => screenManager.setLayoutStrategyStyle(v),
          ),
          _buildCardItem<NumericWidgetStyle>(
            'Numeric Widgets',
            cfg.numericWidgetStyle,
            NumericWidgetStyle.values,
            (v) => screenManager.setNumericWidgetStyle(v),
          ),
          _buildCardItem<WindWidgetStyle>(
            'Wind Widget',
            cfg.windWidgetStyle,
            WindWidgetStyle.values,
            (v) => screenManager.setWindWidgetStyle(v),
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
}
