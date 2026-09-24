import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/flight_model.dart';
import '../../models/lat_lng.dart';
import '../../models/ui_config.dart';
import '../../services/screen_manager_service.dart';
import '../flight/altitude_sparkline_chart.dart';
import '../flight/map_widget.dart';
import '../flight/numeric_text_widget.dart';
import '../flight/thermal_map_widget.dart';
import '../flight/vario_lift_sink_bar.dart';
import '../flight/wind_direction_widget.dart';
import 'widget_picker_sheet.dart';
import 'widget_edit_frame.dart';
import 'widget_inspector_panel.dart';

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
    return ListenableBuilder(
      listenable: screenManager,
      builder: (context, _) {
        final activeScreen = screenManager.activeScreen;
        final strategy = activeScreen.layoutStrategy;
        final isEditMode = screenManager.isEditMode;
        final selectedWidgetId = screenManager.selectedWidgetId;
        final selectedWidget = selectedWidgetId != null
            ? activeScreen.widgets.cast<WidgetPlacementModel?>().firstWhere(
                (w) => w?.id == selectedWidgetId,
                orElse: () => null,
              )
            : null;

        return Stack(
          children: [
            // Core Layout Strategy View
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildLayout(
                  context,
                  strategy,
                  activeScreen,
                  isEditMode,
                  selectedWidgetId,
                ),
              ),
            ),

            // Edit Mode Overlay Controls & Floating Action Button
            if (isEditMode)
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (selectedWidget != null) ...[
                      WidgetInspectorPanel(model: selectedWidget, screenManager: screenManager),
                      const SizedBox(height: 10),
                    ],
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          FloatingActionButton.extended(
                            key: const Key('btn_add_widget'),
                            heroTag: 'add_widget_fab',
                            backgroundColor: Colors.blueAccent,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Widget'),
                            tooltip: 'Add new widget to layout',
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: Colors.transparent,
                                builder: (ctx) => WidgetPickerSheet(
                                  screenManager: screenManager,
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          _buildLayerSelector(
                            context,
                            activeScreen.widgets,
                            selectedWidget,
                          ),
                          const SizedBox(width: 8),
                          FloatingActionButton.extended(
                            key: const Key('btn_done_editing'),
                            heroTag: 'done_edit_fab',
                            backgroundColor: Colors.green,
                            icon: const Icon(Icons.check),
                            label: const Text('Done Editing'),
                            tooltip: 'Save layout and exit edit mode',
                            onPressed: () {
                              screenManager.toggleEditMode(false);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildLayerSelector(
    BuildContext context,
    List<WidgetPlacementModel> widgets,
    WidgetPlacementModel? selectedWidget,
  ) {
    return PopupMenuButton<String>(
      key: const Key('btn_layer_selector'),
      tooltip: 'Select Widget Layer',
      color: Colors.blueGrey.shade900,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.cyanAccent, width: 1.2),
      ),
      onSelected: (widgetId) {
        screenManager.selectWidget(widgetId);
      },
      itemBuilder: (ctx) {
        return widgets.map((w) {
          final isCurrent = w.id == selectedWidget?.id;
          return PopupMenuItem<String>(
            key: Key('layer_item_${w.id}'),
            value: w.id,
            child: Row(
              children: [
                Icon(
                  w.type == WidgetType.map
                      ? Icons.map
                      : w.type == WidgetType.thermalMap
                      ? Icons.wb_sunny
                      : Icons.widgets,
                  color: isCurrent ? Colors.cyanAccent : Colors.white70,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${w.type.name.toUpperCase()} (${w.w}x${w.h} @ ${w.x},${w.y})',
                    style: TextStyle(
                      color: isCurrent ? Colors.cyanAccent : Colors.white,
                      fontWeight: isCurrent
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (isCurrent)
                  const Icon(Icons.check, color: Colors.cyanAccent, size: 14),
              ],
            ),
          );
        }).toList();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.blueGrey.shade900.withAlpha(230),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selectedWidget != null ? Colors.cyanAccent : Colors.white30,
            width: 1.5,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.layers,
              size: 16,
              color: selectedWidget != null
                  ? Colors.cyanAccent
                  : Colors.white70,
            ),
            const SizedBox(width: 6),
            Text(
              selectedWidget != null
                  ? selectedWidget.type.name.toUpperCase()
                  : 'Layers (${widgets.length})',
              style: TextStyle(
                color: selectedWidget != null
                    ? Colors.cyanAccent
                    : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }


  Widget _buildLayout(
    BuildContext context,
    LayoutStrategyStyle strategy,
    FlightScreenModel screen,
    bool isEditMode,
    String? selectedWidgetId,
  ) {
    return LayoutBuilder(
      key: ValueKey('layout_${screen.id}'),
      builder: (ctx, constraints) {
        final totalWidth = constraints.maxWidth;
        final cellWidth = totalWidth / 8;

        // Minimum canvas height cached at FlightScreenModel level (O(1) lookup on layout)
        final maxBottomGrid = screen.maxBottomGrid;
        final effectiveMaxHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 600.0;
        final dynamicCellHeight = (effectiveMaxHeight > 0)
            ? (effectiveMaxHeight / math.max(maxBottomGrid, 8))
            : 55.0;
        final cellHeight = math.max(dynamicCellHeight, 38.0);
        final contentHeight = math.max(
          effectiveMaxHeight,
          (maxBottomGrid * cellHeight) + (isEditMode ? 80.0 : 0.0),
        );

        final Widget layoutView;
        switch (strategy) {
          case LayoutStrategyStyle.freeformHud:
            layoutView = _buildFreeformHud(
              context,
              screen,
              isEditMode,
              selectedWidgetId,
              totalWidth,
              contentHeight,
              cellWidth,
              cellHeight,
            );
          case LayoutStrategyStyle.snapToGrid:
            layoutView = _buildSnapToGrid(
              context,
              screen,
              isEditMode,
              selectedWidgetId,
              totalWidth,
              contentHeight,
              cellWidth,
              cellHeight,
            );
          case LayoutStrategyStyle.sidebarDashboard:
            layoutView = _buildSidebarDashboard(
              context,
              screen,
              isEditMode,
              selectedWidgetId,
              totalWidth,
              contentHeight,
              cellWidth,
              cellHeight,
            );
        }
        if (isEditMode) {
          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => screenManager.selectWidget(null),
            child: layoutView,
          );
        }
        return layoutView;
      },
    );
  }

  // Option 1: Freeform HUD
  Widget _buildFreeformHud(
    BuildContext context,
    FlightScreenModel screen,
    bool isEditMode,
    String? selectedWidgetId,
    double totalWidth,
    double contentHeight,
    double cellWidth,
    double cellHeight,
  ) {
    return Container(
      color: Colors.black.withAlpha(30),
      child: SingleChildScrollView(
        child: SizedBox(
          width: totalWidth,
          height: contentHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (isEditMode) ...[
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.cyanAccent.withAlpha(60),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'FREEFORM HUD (SCREEN CONFIGURATION)',
                        style: TextStyle(
                          color: Colors.cyanAccent.withAlpha(120),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
                ..._buildGridGuides(
                  totalWidth,
                  contentHeight,
                  cellWidth,
                  cellHeight,
                ),
              ],
              ..._getOrderedWidgets(
                screen.widgets,
                isEditMode: isEditMode,
                selectedWidgetId: selectedWidgetId,
              ).map((widgetModel) {
                final left = widgetModel.x * cellWidth;
                final top = widgetModel.y * cellHeight;
                final width = widgetModel.w * cellWidth;
                final height = widgetModel.h * cellHeight;

                return Positioned(
                  key: Key('positioned_${widgetModel.id}'),
                  left: left,
                  top: top,
                  width: width,
                  height: height,
                  child: WidgetEditFrame(
                    model: widgetModel,
                    screenManager: screenManager,
                    isEditMode: isEditMode,
                    cellWidth: cellWidth,
                    cellHeight: cellHeight,
                    child: _renderWidgetContent(widgetModel),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  // Option 2: Snap-to-Grid
  Widget _buildSnapToGrid(
    BuildContext context,
    FlightScreenModel screen,
    bool isEditMode,
    String? selectedWidgetId,
    double totalWidth,
    double contentHeight,
    double cellWidth,
    double cellHeight,
  ) {
    return Container(
      color: Colors.blueGrey.shade900.withAlpha(80),
      child: SingleChildScrollView(
        child: SizedBox(
          width: totalWidth,
          height: contentHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (isEditMode) ...[
                Positioned.fill(
                  child: GridPaper(
                    color: Colors.cyanAccent.withAlpha(40),
                    divisions: 2,
                    subdivisions: 2,
                  ),
                ),
                ..._buildGridGuides(
                  totalWidth,
                  contentHeight,
                  cellWidth,
                  cellHeight,
                ),
              ],
              ..._getOrderedWidgets(
                screen.widgets,
                isEditMode: isEditMode,
                selectedWidgetId: selectedWidgetId,
              ).map((widgetModel) {
                final left = widgetModel.x * cellWidth;
                final top = widgetModel.y * cellHeight;
                final width = widgetModel.w * cellWidth;
                final height = widgetModel.h * cellHeight;

                return Positioned(
                  key: Key('positioned_${widgetModel.id}'),
                  left: left,
                  top: top,
                  width: width,
                  height: height,
                  child: WidgetEditFrame(
                    model: widgetModel,
                    screenManager: screenManager,
                    isEditMode: isEditMode,
                    cellWidth: cellWidth,
                    cellHeight: cellHeight,
                    child: _renderWidgetContent(widgetModel),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  // Option 3: Sidebar Dashboard (Default)
  Widget _buildSidebarDashboard(
    BuildContext context,
    FlightScreenModel screen,
    bool isEditMode,
    String? selectedWidgetId,
    double totalWidth,
    double contentHeight,
    double cellWidth,
    double cellHeight,
  ) {
    return Container(
      color: Colors.black.withAlpha(20),
      child: SingleChildScrollView(
        child: SizedBox(
          width: totalWidth,
          height: contentHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Sidebar background styling for left 2 columns
              Positioned(
                left: 0,
                top: 0,
                width: cellWidth * 2,
                height: contentHeight,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade900.withAlpha(60),
                    border: Border(
                      right: BorderSide(
                        color: isEditMode
                            ? Colors.cyanAccent.withAlpha(80)
                            : Colors.white.withAlpha(20),
                        width: 1.5,
                      ),
                    ),
                  ),
                  child: isEditMode
                      ? Align(
                          alignment: Alignment.topCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'SIDEBAR',
                              style: TextStyle(
                                color: Colors.cyanAccent.withAlpha(80),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                        )
                      : null,
                ),
              ),

              if (isEditMode) ...[
                ..._buildGridGuides(
                  totalWidth,
                  contentHeight,
                  cellWidth,
                  cellHeight,
                ),
              ],

              ..._getOrderedWidgets(
                screen.widgets,
                isEditMode: isEditMode,
                selectedWidgetId: selectedWidgetId,
              ).map((widgetModel) {
                final left = widgetModel.x * cellWidth;
                final top = widgetModel.y * cellHeight;
                final width = widgetModel.w * cellWidth;
                final height = widgetModel.h * cellHeight;

                return Positioned(
                  key: Key('positioned_${widgetModel.id}'),
                  left: left,
                  top: top,
                  width: width,
                  height: height,
                  child: WidgetEditFrame(
                    model: widgetModel,
                    screenManager: screenManager,
                    isEditMode: isEditMode,
                    cellWidth: cellWidth,
                    cellHeight: cellHeight,
                    child: _renderWidgetContent(widgetModel),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  List<WidgetPlacementModel> _getOrderedWidgets(
    List<WidgetPlacementModel> widgets, {
    bool isEditMode = false,
    String? selectedWidgetId,
  }) {
    final list = List<WidgetPlacementModel>.from(widgets);
    if (isEditMode && selectedWidgetId != null) {
      final index = list.indexWhere((w) => w.id == selectedWidgetId);
      if (index != -1) {
        final selected = list.removeAt(index);
        list.add(selected);
      }
    }
    return list;
  }

  List<Widget> _buildGridGuides(
    double totalWidth,
    double totalHeight,
    double cellWidth,
    double cellHeight,
  ) {
    final guides = <Widget>[];
    // Vertical column guides (8 columns)
    for (int col = 1; col < 8; col++) {
      guides.add(
        Positioned(
          left: col * cellWidth,
          top: 0,
          bottom: 0,
          child: Container(
            width: 1,
            color: (col % 2 == 0)
                ? Colors.cyanAccent.withAlpha(50)
                : Colors.cyanAccent.withAlpha(25),
          ),
        ),
      );
    }
    // Horizontal row guides
    final rows = (totalHeight / cellHeight).ceil();
    for (int row = 1; row <= rows; row++) {
      guides.add(
        Positioned(
          left: 0,
          right: 0,
          top: row * cellHeight,
          child: Container(height: 1, color: Colors.cyanAccent.withAlpha(30)),
        ),
      );
    }
    return guides;
  }

  double _parseTelemetryDouble(String key, double defaultValue) {
    return (telemetryData[key] as num?)?.toDouble() ?? defaultValue;
  }

  Widget _renderWidgetContent(WidgetPlacementModel model) {
    final alt = _parseTelemetryDouble('altitude', 1450.0);
    final speed = _parseTelemetryDouble('speed', 42.5);
    final glide = _parseTelemetryDouble('glide', 8.4);
    final hag = _parseTelemetryDouble('hag', 320.0);
    final climb = _parseTelemetryDouble('climb', 1.8);
    final windDeg = _parseTelemetryDouble('windDir', 220.0);
    final windSpd = _parseTelemetryDouble('windSpeed', 14.0);

    final lat = (telemetryData['latitude'] as num?)?.toDouble();
    final lng = (telemetryData['longitude'] as num?)?.toDouble();
    final pilotPos = (lat != null && lng != null) ? LatLng(lat, lng) : null;
    final heading = (telemetryData['heading'] as num?)?.toDouble() ?? windDeg;
    final trackPoints = telemetryData['trackPoints'] as List<LatLng>?;
    final flightPoints =
        (telemetryData['flightPoints'] as List<FlightPoint>?) ??
        (telemetryData['activeFlightPoints'] as List<FlightPoint>?);

    final rawHistory = telemetryData['history'];
    final List<double> history = rawHistory is List<double>
        ? rawHistory
        : (rawHistory as List<dynamic>?)
                  ?.map((e) => (e as num).toDouble())
                  .toList() ??
              const [1400.0, 1410.0, 1430.0, 1425.0, 1450.0];

    switch (model.type) {
      case WidgetType.altitude:
        return RepaintBoundary(
          child: NumericTextWidget(
            label: 'Altitude',
            value: alt.toStringAsFixed(0),
            unit: 'm',
            style: model.effectiveNumericStyle,
          ),
        );
      case WidgetType.speed:
        return RepaintBoundary(
          child: NumericTextWidget(
            label: 'Speed',
            value: speed.toStringAsFixed(1),
            unit: 'km/h',
            style: model.effectiveNumericStyle,
          ),
        );
      case WidgetType.glide:
        return RepaintBoundary(
          child: NumericTextWidget(
            label: 'Glide',
            value: glide.toStringAsFixed(1),
            unit: 'L/D',
            style: model.effectiveNumericStyle,
          ),
        );
      case WidgetType.hag:
        return RepaintBoundary(
          child: NumericTextWidget(
            label: 'HAG',
            value: hag.toStringAsFixed(0),
            unit: 'm AGL',
            style: model.effectiveNumericStyle,
          ),
        );
      case WidgetType.windDirection:
        return RepaintBoundary(
          child: WindDirectionWidget(
            directionDegrees: windDeg,
            speedKmH: windSpd,
            style: model.effectiveWindStyle,
          ),
        );
      case WidgetType.varioBar:
        return RepaintBoundary(
          child: VarioLiftSinkBar(
            climbRateMs: climb,
            style: model.effectiveVarioStyle,
          ),
        );
      case WidgetType.altitudeChart:
        return RepaintBoundary(
          child: AltitudeSparklineChart(
            history: history,
            style: model.effectiveAltitudeChartStyle,
          ),
        );
      case WidgetType.map:
        return RepaintBoundary(
          child: MapWidget(
            key: ValueKey('map_widget_${model.id}'),
            style: model.effectiveMapStyle,
            orientation: model.effectiveMapOrientation,
            showAirspace: model.effectiveMapShowAirspace,
            showThermals: model.effectiveMapShowThermals,
            showTrack: model.effectiveMapShowTrack,
            showContours: model.effectiveMapShowContours,
            initialZoom: model.effectiveMapZoomLevel,
            altitudeM: alt,
            speedKmh: speed,
            climbRateMs: climb,
            headingDeg: heading,
            altitudeHistory: history,
            pilotPosition: pilotPos,
            trackPoints: trackPoints,
            flightPoints: flightPoints,
            mapTrackHistoryMinutes: model.effectiveMapTrackHistoryMinutes,
            mapTrackShowOlderTail: model.effectiveMapTrackShowOlderTail,
          ),
        );
      case WidgetType.thermalMap:
        return RepaintBoundary(
          child: ThermalMapWidget(
            style: model.effectiveThermalMapStyle,
            showCore: model.effectiveThermalMapShowCore,
            historySeconds: model.effectiveThermalMapHistorySeconds,
            altitudeM: alt,
            speedKmh: speed,
            climbRateMs: climb,
            headingDeg: windDeg,
            windDirDeg: windDeg,
            windSpeedKmh: windSpd,
          ),
        );
    }
  }
}

