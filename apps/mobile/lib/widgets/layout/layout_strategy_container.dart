import 'package:flutter/material.dart';
import '../../models/ui_config.dart';
import '../../services/screen_manager_service.dart';
import '../flight/altitude_sparkline_chart.dart';
import '../flight/numeric_text_widget.dart';
import '../flight/vario_lift_sink_bar.dart';
import '../flight/wind_direction_widget.dart';
import 'widget_picker_sheet.dart';

class LayoutStrategyContainer extends StatelessWidget {
  const LayoutStrategyContainer({
    super.key,
    required this.screenManager,
    required this.telemetryData,
  });

  final ScreenManagerService screenManager;
  final Map<String, dynamic> telemetryData;

  @override
  Widget build(BuildContext context) {
    final activeScreen = screenManager.activeScreen;
    final strategy = screenManager.config.layoutStrategyStyle;
    final isEditMode = screenManager.isEditMode;

    return Stack(
      children: [
        // Core Layout Strategy View
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _buildLayout(context, strategy, activeScreen, isEditMode),
          ),
        ),

        // Edit Mode Overlay Controls & Floating Action Button
        if (isEditMode)
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'add_widget_fab',
                  backgroundColor: Colors.blueAccent,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Widget'),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      builder: (ctx) =>
                          WidgetPickerSheet(screenManager: screenManager),
                    );
                  },
                ),
                FloatingActionButton.extended(
                  heroTag: 'done_edit_fab',
                  backgroundColor: Colors.green,
                  icon: const Icon(Icons.check),
                  label: const Text('Done Editing'),
                  onPressed: () {
                    screenManager.toggleEditMode(false);
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildLayout(
    BuildContext context,
    LayoutStrategyStyle strategy,
    FlightScreenModel screen,
    bool isEditMode,
  ) {
    switch (strategy) {
      case LayoutStrategyStyle.freeformHud:
        return _buildFreeformHud(context, screen, isEditMode);
      case LayoutStrategyStyle.snapToGrid:
        return _buildSnapToGrid(context, screen, isEditMode);
      case LayoutStrategyStyle.sidebarDashboard:
        return _buildSidebarDashboard(context, screen, isEditMode);
    }
  }

  // Option 1: Freeform HUD
  Widget _buildFreeformHud(
    BuildContext context,
    FlightScreenModel screen,
    bool isEditMode,
  ) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        return Container(
          color: Colors.black.withAlpha(20),
          child: Stack(
            children: [
              if (isEditMode)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.cyanAccent.withAlpha(50),
                        width: 2,
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        'FREEFORM HUD EDIT MODE',
                        style: TextStyle(
                          color: Colors.cyanAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ...screen.widgets.map((widgetModel) {
                final left = (widgetModel.x * (w / 4)).clamp(0.0, w - 120);
                final top = (widgetModel.y * (h / 4)).clamp(0.0, h - 80);
                final width = (widgetModel.w * (w / 4)).clamp(120.0, w);
                final height = (widgetModel.h * (h / 4)).clamp(80.0, h);

                return Positioned(
                  left: left,
                  top: top,
                  width: width,
                  height: height,
                  child: _buildWidgetWrapper(context, widgetModel, isEditMode),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // Option 2: Snap-to-Grid
  Widget _buildSnapToGrid(
    BuildContext context,
    FlightScreenModel screen,
    bool isEditMode,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Stack(
        children: [
          if (isEditMode)
            Positioned.fill(
              child: GridPaper(
                color: Colors.cyanAccent.withAlpha(40),
                divisions: 2,
                subdivisions: 2,
              ),
            ),
          GridView.builder(
            physics: const ClampingScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.6,
            ),
            itemCount: screen.widgets.length,
            itemBuilder: (ctx, index) {
              final widgetModel = screen.widgets[index];
              return _buildWidgetWrapper(context, widgetModel, isEditMode);
            },
          ),
        ],
      ),
    );
  }

  // Option 3: Sidebar Dashboard (Default)
  Widget _buildSidebarDashboard(
    BuildContext context,
    FlightScreenModel screen,
    bool isEditMode,
  ) {
    final varioWidgets = screen.widgets
        .where((w) => w.type == WidgetType.varioBar)
        .toList();
    final mainWidgets = screen.widgets
        .where((w) => w.type != WidgetType.varioBar)
        .toList();

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sidebar Column (Vario Lift/Sink)
          if (varioWidgets.isNotEmpty || isEditMode)
            SizedBox(
              width: 76,
              child: Column(
                children: [
                  for (final widgetModel in varioWidgets)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildWidgetWrapper(
                        context,
                        widgetModel,
                        isEditMode,
                      ),
                    ),
                ],
              ),
            ),
          if (varioWidgets.isNotEmpty || isEditMode) const SizedBox(width: 12),

          // Main Dashboard Grid
          Expanded(
            child: Container(
              decoration: isEditMode
                  ? BoxDecoration(
                      border: Border.all(
                        color: Colors.yellowAccent.withAlpha(100),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    )
                  : null,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final widgetModel in mainWidgets)
                    SizedBox(
                      width: 160,
                      height: 100,
                      child: _buildWidgetWrapper(
                        context,
                        widgetModel,
                        isEditMode,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWidgetWrapper(
    BuildContext context,
    WidgetPlacementModel model,
    bool isEditMode,
  ) {
    final content = _renderWidgetContent(model);

    if (!isEditMode) {
      return content;
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.cyanAccent, width: 2),
        borderRadius: BorderRadius.circular(12),
        color: Colors.blueGrey.shade900.withAlpha(150),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(6),
            child: Opacity(opacity: 0.8, child: content),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: CircleAvatar(
              radius: 14,
              backgroundColor: Colors.redAccent,
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.delete, size: 14, color: Colors.white),
                onPressed: () => screenManager.removeWidget(model.id),
              ),
            ),
          ),
          Positioned(
            bottom: 2,
            left: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              color: Colors.black87,
              child: Text(
                '${model.type.name.toUpperCase()} (Grid: ${model.w}x${model.h})',
                style: const TextStyle(color: Colors.cyanAccent, fontSize: 9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _renderWidgetContent(WidgetPlacementModel model) {
    final cfg = screenManager.config;
    final alt = (telemetryData['altitude'] as num?)?.toDouble() ?? 1450.0;
    final speed = (telemetryData['speed'] as num?)?.toDouble() ?? 42.5;
    final glide = (telemetryData['glide'] as num?)?.toDouble() ?? 8.4;
    final hag = (telemetryData['hag'] as num?)?.toDouble() ?? 320.0;
    final climb = (telemetryData['climb'] as num?)?.toDouble() ?? 1.8;
    final windDeg = (telemetryData['windDir'] as num?)?.toDouble() ?? 220.0;
    final windSpd = (telemetryData['windSpeed'] as num?)?.toDouble() ?? 14.0;
    final history =
        (telemetryData['history'] as List<dynamic>?)
            ?.map((e) => (e as num).toDouble())
            .toList() ??
        [1400.0, 1410.0, 1430.0, 1425.0, 1450.0];

    switch (model.type) {
      case WidgetType.altitude:
        return NumericTextWidget(
          label: 'Altitude',
          value: alt.toStringAsFixed(0),
          unit: 'm',
          style: cfg.numericWidgetStyle,
        );
      case WidgetType.speed:
        return NumericTextWidget(
          label: 'Speed',
          value: speed.toStringAsFixed(1),
          unit: 'km/h',
          style: cfg.numericWidgetStyle,
        );
      case WidgetType.glide:
        return NumericTextWidget(
          label: 'Glide',
          value: glide.toStringAsFixed(1),
          unit: 'L/D',
          style: cfg.numericWidgetStyle,
        );
      case WidgetType.hag:
        return NumericTextWidget(
          label: 'HAG',
          value: hag.toStringAsFixed(0),
          unit: 'm AGL',
          style: cfg.numericWidgetStyle,
        );
      case WidgetType.windDirection:
        return WindDirectionWidget(
          directionDegrees: windDeg,
          speedKmH: windSpd,
          style: cfg.windWidgetStyle,
        );
      case WidgetType.varioBar:
        return VarioLiftSinkBar(
          climbRateMs: climb,
          style: cfg.liftSinkBarStyle,
        );
      case WidgetType.altitudeChart:
        return AltitudeSparklineChart(
          history: history,
          style: cfg.altitudeChartStyle,
        );
    }
  }
}
