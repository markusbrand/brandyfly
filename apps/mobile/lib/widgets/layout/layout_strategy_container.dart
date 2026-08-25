import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../../models/ui_config.dart';
import '../../services/screen_manager_service.dart';
import '../flight/altitude_sparkline_chart.dart';
import '../flight/map_widget.dart';
import '../flight/numeric_text_widget.dart';
import '../flight/thermal_map_widget.dart';
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
    final strategy = activeScreen.layoutStrategy;
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
            bottom: 16,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                FloatingActionButton.extended(
                  key: const Key('btn_add_widget'),
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
                  key: const Key('btn_done_editing'),
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
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final totalWidth = constraints.maxWidth;
        final cellWidth = totalWidth / 4;
        const cellHeight = 110.0;

        // Calculate minimum canvas height to accommodate all widgets
        int maxBottomGrid = 4;
        for (final w in screen.widgets) {
          final bottom = w.y + w.h;
          if (bottom > maxBottomGrid) {
            maxBottomGrid = bottom;
          }
        }
        final contentHeight = math.max(
          constraints.maxHeight,
          (maxBottomGrid * cellHeight) + (isEditMode ? 100.0 : 40.0),
        );

        switch (strategy) {
          case LayoutStrategyStyle.freeformHud:
            return _buildFreeformHud(
              context,
              screen,
              isEditMode,
              totalWidth,
              contentHeight,
              cellWidth,
              cellHeight,
            );
          case LayoutStrategyStyle.snapToGrid:
            return _buildSnapToGrid(
              context,
              screen,
              isEditMode,
              totalWidth,
              contentHeight,
              cellWidth,
              cellHeight,
            );
          case LayoutStrategyStyle.sidebarDashboard:
            return _buildSidebarDashboard(
              context,
              screen,
              isEditMode,
              totalWidth,
              contentHeight,
              cellWidth,
              cellHeight,
            );
        }
      },
    );
  }

  // Option 1: Freeform HUD
  Widget _buildFreeformHud(
    BuildContext context,
    FlightScreenModel screen,
    bool isEditMode,
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
                ..._buildGridGuides(totalWidth, contentHeight, cellWidth, cellHeight),
              ],
              ..._getOrderedWidgets(screen.widgets).map((widgetModel) {
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
                  child: _WidgetEditFrame(
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
                ..._buildGridGuides(totalWidth, contentHeight, cellWidth, cellHeight),
              ],
              ..._getOrderedWidgets(screen.widgets).map((widgetModel) {
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
                  child: _WidgetEditFrame(
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
              // Sidebar background styling for column 0
              Positioned(
                left: 0,
                top: 0,
                width: cellWidth,
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
                ..._buildGridGuides(totalWidth, contentHeight, cellWidth, cellHeight),
              ],

              ..._getOrderedWidgets(screen.widgets).map((widgetModel) {
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
                  child: _WidgetEditFrame(
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

  List<WidgetPlacementModel> _getOrderedWidgets(List<WidgetPlacementModel> widgets) {
    final list = List<WidgetPlacementModel>.from(widgets);
    list.sort((a, b) {
      int layerOf(WidgetType t) {
        if (t == WidgetType.map) return 0;
        if (t == WidgetType.thermalMap) return 1;
        return 2;
      }
      return layerOf(a.type).compareTo(layerOf(b.type));
    });
    return list;
  }

  List<Widget> _buildGridGuides(
    double totalWidth,
    double totalHeight,
    double cellWidth,
    double cellHeight,
  ) {
    final guides = <Widget>[];
    // Vertical column guides (4 columns)
    for (int col = 1; col < 4; col++) {
      guides.add(
        Positioned(
          left: col * cellWidth,
          top: 0,
          bottom: 0,
          child: Container(
            width: 1,
            color: Colors.cyanAccent.withAlpha(30),
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
          child: Container(
            height: 1,
            color: Colors.cyanAccent.withAlpha(30),
          ),
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
    final history =
        (telemetryData['history'] as List<dynamic>?)
            ?.map((e) => (e as num).toDouble())
            .toList() ??
        [1400.0, 1410.0, 1430.0, 1425.0, 1450.0];

    final lat = (telemetryData['latitude'] as num?)?.toDouble();
    final lng = (telemetryData['longitude'] as num?)?.toDouble();
    final pilotPos = (lat != null && lng != null) ? LatLng(lat, lng) : null;
    final heading = (telemetryData['heading'] as num?)?.toDouble() ?? windDeg;
    final trackPoints = telemetryData['trackPoints'] as List<LatLng>?;

    switch (model.type) {
      case WidgetType.altitude:
        return NumericTextWidget(
          label: 'Altitude',
          value: alt.toStringAsFixed(0),
          unit: 'm',
          style: model.effectiveNumericStyle,
        );
      case WidgetType.speed:
        return NumericTextWidget(
          label: 'Speed',
          value: speed.toStringAsFixed(1),
          unit: 'km/h',
          style: model.effectiveNumericStyle,
        );
      case WidgetType.glide:
        return NumericTextWidget(
          label: 'Glide',
          value: glide.toStringAsFixed(1),
          unit: 'L/D',
          style: model.effectiveNumericStyle,
        );
      case WidgetType.hag:
        return NumericTextWidget(
          label: 'HAG',
          value: hag.toStringAsFixed(0),
          unit: 'm AGL',
          style: model.effectiveNumericStyle,
        );
      case WidgetType.windDirection:
        return WindDirectionWidget(
          directionDegrees: windDeg,
          speedKmH: windSpd,
          style: model.effectiveWindStyle,
        );
      case WidgetType.varioBar:
        return VarioLiftSinkBar(
          climbRateMs: climb,
          style: model.effectiveVarioStyle,
        );
      case WidgetType.altitudeChart:
        return AltitudeSparklineChart(
          history: history,
          style: model.effectiveAltitudeChartStyle,
        );
      case WidgetType.map:
        return MapWidget(
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
        );
      case WidgetType.thermalMap:
        return ThermalMapWidget(
          style: model.effectiveThermalMapStyle,
          showCore: model.effectiveThermalMapShowCore,
          historySeconds: model.effectiveThermalMapHistorySeconds,
          altitudeM: alt,
          speedKmh: speed,
          climbRateMs: climb,
          headingDeg: windDeg,
          windDirDeg: windDeg,
          windSpeedKmh: windSpd,
        );
    }
  }
}

class _WidgetEditFrame extends StatefulWidget {
  const _WidgetEditFrame({
    required this.model,
    required this.screenManager,
    required this.isEditMode,
    required this.cellWidth,
    required this.cellHeight,
    required this.child,
  });

  final WidgetPlacementModel model;
  final ScreenManagerService screenManager;
  final bool isEditMode;
  final double cellWidth;
  final double cellHeight;
  final Widget child;

  @override
  State<_WidgetEditFrame> createState() => _WidgetEditFrameState();
}

class _WidgetEditFrameState extends State<_WidgetEditFrame> {
  double _dragAccumX = 0;
  double _dragAccumY = 0;

  double _resizeAccumX = 0;
  double _resizeAccumY = 0;

  @override
  Widget build(BuildContext context) {
    if (!widget.isEditMode) {
      final isMap = widget.model.type == WidgetType.map;
      return Padding(
        padding: isMap ? EdgeInsets.zero : const EdgeInsets.all(4.0),
        child: SizedBox.expand(
          child: widget.child,
        ),
      );
    }

    final model = widget.model;
    final id = model.id;
    final typeName = model.type.name.toUpperCase();

    return Padding(
      padding: const EdgeInsets.all(3.0),
      child: Container(
        key: Key('widget_box_$id'),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.cyanAccent, width: 1.5),
          borderRadius: BorderRadius.circular(10),
          color: Colors.blueGrey.shade900.withAlpha(200),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Widget Content (Scales to fill allotted frame space)
            Positioned.fill(
              top: 26,
              bottom: 26,
              left: 4,
              right: 4,
              child: ClipRect(
                child: Opacity(
                  opacity: 0.9,
                  child: SizedBox.expand(
                    child: widget.child,
                  ),
                ),
              ),
            ),

            // Top Header: Drag Handle & Info & Actions
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 24,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (_) {
                  _dragAccumX = 0;
                  _dragAccumY = 0;
                },
                onPanUpdate: (details) {
                  _dragAccumX += details.delta.dx;
                  _dragAccumY += details.delta.dy;

                  int dx = 0;
                  int dy = 0;
                  if (_dragAccumX > widget.cellWidth * 0.4) {
                    dx = 1;
                    _dragAccumX = 0;
                  } else if (_dragAccumX < -widget.cellWidth * 0.4) {
                    dx = -1;
                    _dragAccumX = 0;
                  }

                  if (_dragAccumY > widget.cellHeight * 0.4) {
                    dy = 1;
                    _dragAccumY = 0;
                  } else if (_dragAccumY < -widget.cellHeight * 0.4) {
                    dy = -1;
                    _dragAccumY = 0;
                  }

                  if (dx != 0 || dy != 0) {
                    widget.screenManager.moveWidget(id, dx, dy);
                  }
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.move,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.cyan.shade900.withAlpha(220),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.drag_indicator, size: 14, color: Colors.cyanAccent),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            '$typeName [${model.x},${model.y} ${model.w}x${model.h}]',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Configure Dialog Button
                        InkWell(
                          key: Key('btn_config_$id'),
                          onTap: () => _showConfigDialog(context),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 2),
                            child: Icon(Icons.tune, size: 14, color: Colors.white70),
                          ),
                        ),
                        // Delete Button
                        InkWell(
                          key: Key('btn_delete_$id'),
                          onTap: () => widget.screenManager.removeWidget(id),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 2),
                            child: Icon(Icons.close, size: 14, color: Colors.redAccent),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Toolbar: Stepper Resize & Nudge Move Controls
            Positioned(
              bottom: 0,
              left: 0,
              right: 26,
              height: 24,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Position nudge arrows
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _miniButton(
                            key: Key('btn_move_left_$id'),
                            icon: Icons.chevron_left,
                            tooltip: 'Move Left',
                            enabled: model.x > 0,
                            onPressed: () => widget.screenManager.moveWidget(id, -1, 0),
                          ),
                          _miniButton(
                            key: Key('btn_move_right_$id'),
                            icon: Icons.chevron_right,
                            tooltip: 'Move Right',
                            enabled: model.x + model.w < 4,
                            onPressed: () => widget.screenManager.moveWidget(id, 1, 0),
                          ),
                          _miniButton(
                            key: Key('btn_move_up_$id'),
                            icon: Icons.expand_less,
                            tooltip: 'Move Up',
                            enabled: model.y > 0,
                            onPressed: () => widget.screenManager.moveWidget(id, 0, -1),
                          ),
                          _miniButton(
                            key: Key('btn_move_down_$id'),
                            icon: Icons.expand_more,
                            tooltip: 'Move Down',
                            enabled: true,
                            onPressed: () => widget.screenManager.moveWidget(id, 0, 1),
                          ),
                        ],
                      ),
                      const SizedBox(width: 2),
                      // Size steppers (Width +/- and Height +/-)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Width dec/inc
                          _textMiniButton(
                            key: Key('btn_dec_width_$id'),
                            label: 'W-',
                            tooltip: 'Decrease Width',
                            enabled: model.w > 1,
                            onPressed: () => widget.screenManager.resizeWidget(id, -1, 0),
                          ),
                          _textMiniButton(
                            key: Key('btn_inc_width_$id'),
                            label: 'W+',
                            tooltip: 'Increase Width',
                            enabled: model.x + model.w < 4,
                            onPressed: () => widget.screenManager.resizeWidget(id, 1, 0),
                          ),
                          const SizedBox(width: 2),
                          // Height dec/inc
                          _textMiniButton(
                            key: Key('btn_dec_height_$id'),
                            label: 'H-',
                            tooltip: 'Decrease Height',
                            enabled: model.h > 1,
                            onPressed: () => widget.screenManager.resizeWidget(id, 0, -1),
                          ),
                          _textMiniButton(
                            key: Key('btn_inc_height_$id'),
                            label: 'H+',
                            tooltip: 'Increase Height',
                            enabled: model.h < 6,
                            onPressed: () => widget.screenManager.resizeWidget(id, 0, 1),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // OS-Style Corner Drag & Drop Resize Handle
            Positioned(
              bottom: 0,
              right: 0,
              width: 26,
              height: 24,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeDownRight,
                child: GestureDetector(
                  key: Key('resize_handle_$id'),
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (_) {
                    _resizeAccumX = 0;
                    _resizeAccumY = 0;
                  },
                  onPanUpdate: (details) {
                    _resizeAccumX += details.delta.dx;
                    _resizeAccumY += details.delta.dy;

                    int dw = 0;
                    int dh = 0;
                    if (_resizeAccumX > widget.cellWidth * 0.3) {
                      dw = 1;
                      _resizeAccumX = 0;
                    } else if (_resizeAccumX < -widget.cellWidth * 0.3) {
                      dw = -1;
                      _resizeAccumX = 0;
                    }

                    if (_resizeAccumY > widget.cellHeight * 0.3) {
                      dh = 1;
                      _resizeAccumY = 0;
                    } else if (_resizeAccumY < -widget.cellHeight * 0.3) {
                      dh = -1;
                      _resizeAccumY = 0;
                    }

                    if (dw != 0 || dh != 0) {
                      widget.screenManager.resizeWidget(id, dw, dh);
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.cyan.shade900.withAlpha(220),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(6),
                        bottomRight: Radius.circular(8),
                      ),
                      border: Border.all(
                        color: Colors.cyanAccent.withAlpha(160),
                        width: 1,
                      ),
                    ),
                    child: const Tooltip(
                      message: 'Drag corner to resize',
                      child: Center(
                        child: Icon(
                          Icons.south_east,
                          size: 14,
                          color: Colors.cyanAccent,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniButton({
    required Key key,
    required IconData icon,
    required String tooltip,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        key: key,
        onTap: enabled ? onPressed : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: Icon(
            icon,
            size: 15,
            color: enabled ? Colors.cyanAccent : Colors.white24,
          ),
        ),
      ),
    );
  }

  Widget _textMiniButton({
    required Key key,
    required String label,
    required String tooltip,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        key: key,
        onTap: enabled ? onPressed : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: BoxDecoration(
            color: enabled ? Colors.blueGrey.shade800 : Colors.black45,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: enabled ? Colors.white : Colors.white24,
            ),
          ),
        ),
      ),
    );
  }

  void _showConfigDialog(BuildContext context) {
    final model = widget.model;
    int curX = model.x;
    int curY = model.y;
    int curW = model.w;
    int curH = model.h;

    NumericWidgetStyle curNumericStyle = model.effectiveNumericStyle;
    WindWidgetStyle curWindStyle = model.effectiveWindStyle;
    LiftSinkBarStyle curVarioStyle = model.effectiveVarioStyle;
    AltitudeChartStyle curAltitudeChartStyle = model.effectiveAltitudeChartStyle;
    MapWidgetStyle curMapStyle = model.effectiveMapStyle;
    MapOrientation curMapOrientation = model.effectiveMapOrientation;
    bool curMapAirspace = model.effectiveMapShowAirspace;
    bool curMapThermals = model.effectiveMapShowThermals;
    bool curMapTrack = model.effectiveMapShowTrack;
    bool curMapContours = model.effectiveMapShowContours;
    double curMapZoomLevel = model.effectiveMapZoomLevel;
    ThermalMapStyle curThermalMapStyle = model.effectiveThermalMapStyle;
    bool curThermalMapShowCore = model.effectiveThermalMapShowCore;
    int curThermalMapHistorySeconds = model.effectiveThermalMapHistorySeconds;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.blueGrey.shade900,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.tune, color: Colors.cyanAccent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Configure ${model.type.name.toUpperCase()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section 1: Position and Dimensions
                      _buildSectionTitle('Position & Size'),
                      Card(
                        color: Colors.black38,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Position X:', style: TextStyle(color: Colors.white70)),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove, size: 18),
                                        onPressed: curX > 0
                                            ? () => setDialogState(() => curX--)
                                            : null,
                                      ),
                                      Text('$curX', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      IconButton(
                                        icon: const Icon(Icons.add, size: 18),
                                        onPressed: curX + curW < 4
                                            ? () => setDialogState(() => curX++)
                                            : null,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Position Y:', style: TextStyle(color: Colors.white70)),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove, size: 18),
                                        onPressed: curY > 0
                                            ? () => setDialogState(() => curY--)
                                            : null,
                                      ),
                                      Text('$curY', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      IconButton(
                                        icon: const Icon(Icons.add, size: 18),
                                        onPressed: () => setDialogState(() => curY++),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Width:', style: TextStyle(color: Colors.white70)),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove, size: 18),
                                        onPressed: curW > 1
                                            ? () => setDialogState(() => curW--)
                                            : null,
                                      ),
                                      Text('$curW', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      IconButton(
                                        icon: const Icon(Icons.add, size: 18),
                                        onPressed: curX + curW < 4
                                            ? () => setDialogState(() => curW++)
                                            : null,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Height:', style: TextStyle(color: Colors.white70)),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove, size: 18),
                                        onPressed: curH > 1
                                            ? () => setDialogState(() => curH--)
                                            : null,
                                      ),
                                      Text('$curH', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      IconButton(
                                        icon: const Icon(Icons.add, size: 18),
                                        onPressed: curH < 6
                                            ? () => setDialogState(() => curH++)
                                            : null,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Section 2: Widget-specific configuration
                      if (model.type == WidgetType.altitude ||
                          model.type == WidgetType.speed ||
                          model.type == WidgetType.glide ||
                          model.type == WidgetType.hag) ...[
                        _buildSectionTitle('Numeric Display Style'),
                        Card(
                          color: Colors.black38,
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _styleChip<NumericWidgetStyle>(
                                  label: 'Minimalist',
                                  value: NumericWidgetStyle.minimalistText,
                                  selectedValue: curNumericStyle,
                                  onSelected: (val) => setDialogState(() => curNumericStyle = val),
                                ),
                                _styleChip<NumericWidgetStyle>(
                                  label: 'High Contrast',
                                  value: NumericWidgetStyle.highContrastBox,
                                  selectedValue: curNumericStyle,
                                  onSelected: (val) => setDialogState(() => curNumericStyle = val),
                                ),
                                _styleChip<NumericWidgetStyle>(
                                  label: 'Circular Gauge',
                                  value: NumericWidgetStyle.circularGauge,
                                  selectedValue: curNumericStyle,
                                  onSelected: (val) => setDialogState(() => curNumericStyle = val),
                                ),
                                _styleChip<NumericWidgetStyle>(
                                  label: 'Retro Digital',
                                  value: NumericWidgetStyle.retroDigital,
                                  selectedValue: curNumericStyle,
                                  onSelected: (val) => setDialogState(() => curNumericStyle = val),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else if (model.type == WidgetType.windDirection) ...[
                        _buildSectionTitle('Wind Widget Style'),
                        Card(
                          color: Colors.black38,
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _styleChip<WindWidgetStyle>(
                                  label: 'Relative Arrow',
                                  value: WindWidgetStyle.relativeArrow,
                                  selectedValue: curWindStyle,
                                  onSelected: (val) => setDialogState(() => curWindStyle = val),
                                ),
                                _styleChip<WindWidgetStyle>(
                                  label: 'Compass Rose',
                                  value: WindWidgetStyle.miniCompassRose,
                                  selectedValue: curWindStyle,
                                  onSelected: (val) => setDialogState(() => curWindStyle = val),
                                ),
                                _styleChip<WindWidgetStyle>(
                                  label: 'Windsock',
                                  value: WindWidgetStyle.windsockIndicator,
                                  selectedValue: curWindStyle,
                                  onSelected: (val) => setDialogState(() => curWindStyle = val),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else if (model.type == WidgetType.varioBar) ...[
                        _buildSectionTitle('Vario Bar Style'),
                        Card(
                          color: Colors.black38,
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _styleChip<LiftSinkBarStyle>(
                                  label: 'Vertical Edge Bar',
                                  value: LiftSinkBarStyle.verticalEdgeBar,
                                  selectedValue: curVarioStyle,
                                  onSelected: (val) => setDialogState(() => curVarioStyle = val),
                                ),
                                _styleChip<LiftSinkBarStyle>(
                                  label: 'Analog Dial',
                                  value: LiftSinkBarStyle.analogDial,
                                  selectedValue: curVarioStyle,
                                  onSelected: (val) => setDialogState(() => curVarioStyle = val),
                                ),
                                _styleChip<LiftSinkBarStyle>(
                                  label: 'Edge Glow',
                                  value: LiftSinkBarStyle.screenEdgeGlow,
                                  selectedValue: curVarioStyle,
                                  onSelected: (val) => setDialogState(() => curVarioStyle = val),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else if (model.type == WidgetType.altitudeChart) ...[
                        _buildSectionTitle('Altitude Chart Style'),
                        Card(
                          color: Colors.black38,
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _styleChip<AltitudeChartStyle>(
                                  label: 'Sparkline',
                                  value: AltitudeChartStyle.minimalSparkline,
                                  selectedValue: curAltitudeChartStyle,
                                  onSelected: (val) => setDialogState(() => curAltitudeChartStyle = val),
                                ),
                                _styleChip<AltitudeChartStyle>(
                                  label: 'Filled Area',
                                  value: AltitudeChartStyle.filledAreaGraph,
                                  selectedValue: curAltitudeChartStyle,
                                  onSelected: (val) => setDialogState(() => curAltitudeChartStyle = val),
                                ),
                                _styleChip<AltitudeChartStyle>(
                                  label: 'Detailed Grid',
                                  value: AltitudeChartStyle.detailedGrid,
                                  selectedValue: curAltitudeChartStyle,
                                  onSelected: (val) => setDialogState(() => curAltitudeChartStyle = val),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else if (model.type == WidgetType.map) ...[
                        _buildSectionTitle('Map Style'),
                        Card(
                          color: Colors.black38,
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _styleChip<MapWidgetStyle>(
                                  label: 'Alpine Topo',
                                  value: MapWidgetStyle.topoContours,
                                  selectedValue: curMapStyle,
                                  onSelected: (val) => setDialogState(() => curMapStyle = val),
                                ),
                                _styleChip<MapWidgetStyle>(
                                  label: 'Vector HUD',
                                  value: MapWidgetStyle.minimalVector,
                                  selectedValue: curMapStyle,
                                  onSelected: (val) => setDialogState(() => curMapStyle = val),
                                ),
                                _styleChip<MapWidgetStyle>(
                                  label: 'Thermal Radar',
                                  value: MapWidgetStyle.thermalHeatmap,
                                  selectedValue: curMapStyle,
                                  onSelected: (val) => setDialogState(() => curMapStyle = val),
                                ),
                                _styleChip<MapWidgetStyle>(
                                  label: 'Shaded Relief',
                                  value: MapWidgetStyle.satelliteTerrain,
                                  selectedValue: curMapStyle,
                                  onSelected: (val) => setDialogState(() => curMapStyle = val),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildSectionTitle('Initial Zoom Level'),
                        Card(
                          color: Colors.black38,
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Zoom: ${curMapZoomLevel.toStringAsFixed(1)}x',
                                      style: const TextStyle(
                                        color: Colors.cyanAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          key: const Key('btn_config_zoom_decrease'),
                                          icon: const Icon(Icons.remove, size: 18),
                                          onPressed: curMapZoomLevel > 3.0
                                              ? () => setDialogState(() => curMapZoomLevel = (curMapZoomLevel - 0.5).clamp(3.0, 18.0))
                                              : null,
                                        ),
                                        IconButton(
                                          key: const Key('btn_config_zoom_increase'),
                                          icon: const Icon(Icons.add, size: 18),
                                          onPressed: curMapZoomLevel < 18.0
                                              ? () => setDialogState(() => curMapZoomLevel = (curMapZoomLevel + 0.5).clamp(3.0, 18.0))
                                              : null,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Slider(
                                  key: const Key('slider_config_zoom'),
                                  value: curMapZoomLevel.clamp(3.0, 18.0),
                                  min: 3.0,
                                  max: 18.0,
                                  divisions: 30,
                                  label: '${curMapZoomLevel.toStringAsFixed(1)}x',
                                  activeColor: Colors.cyanAccent,
                                  onChanged: (val) => setDialogState(() => curMapZoomLevel = val),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Presets:',
                                  style: TextStyle(color: Colors.white60, fontSize: 11),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    ActionChip(
                                      label: const Text('Overview (10.0x)', style: TextStyle(fontSize: 10, color: Colors.white70)),
                                      backgroundColor: Colors.black45,
                                      onPressed: () => setDialogState(() => curMapZoomLevel = 10.0),
                                    ),
                                    ActionChip(
                                      label: const Text('XC Cruise (13.5x)', style: TextStyle(fontSize: 10, color: Colors.white70)),
                                      backgroundColor: Colors.black45,
                                      onPressed: () => setDialogState(() => curMapZoomLevel = 13.5),
                                    ),
                                    ActionChip(
                                      label: const Text('Thermal (15.5x)', style: TextStyle(fontSize: 10, color: Colors.white70)),
                                      backgroundColor: Colors.black45,
                                      onPressed: () => setDialogState(() => curMapZoomLevel = 15.5),
                                    ),
                                    ActionChip(
                                      label: const Text('LZ Final (16.5x)', style: TextStyle(fontSize: 10, color: Colors.white70)),
                                      backgroundColor: Colors.black45,
                                      onPressed: () => setDialogState(() => curMapZoomLevel = 16.5),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildSectionTitle('Map Orientation'),
                        Card(
                          color: Colors.black38,
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _styleChip<MapOrientation>(
                                  label: 'Track Up',
                                  value: MapOrientation.trackUp,
                                  selectedValue: curMapOrientation,
                                  onSelected: (val) => setDialogState(() => curMapOrientation = val),
                                ),
                                _styleChip<MapOrientation>(
                                  label: 'North Up',
                                  value: MapOrientation.northUp,
                                  selectedValue: curMapOrientation,
                                  onSelected: (val) => setDialogState(() => curMapOrientation = val),
                                ),
                                _styleChip<MapOrientation>(
                                  label: 'Heading Up',
                                  value: MapOrientation.headingUp,
                                  selectedValue: curMapOrientation,
                                  onSelected: (val) => setDialogState(() => curMapOrientation = val),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildSectionTitle('Map Layer Overlays'),
                        Card(
                          color: Colors.black38,
                          child: Column(
                            children: [
                              SwitchListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                title: const Text('Airspaces (CTR / TMA)', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                value: curMapAirspace,
                                activeThumbColor: Colors.cyanAccent,
                                onChanged: (val) => setDialogState(() => curMapAirspace = val),
                              ),
                              SwitchListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                title: const Text('Thermal Updraft Hotspots', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                value: curMapThermals,
                                activeThumbColor: Colors.cyanAccent,
                                onChanged: (val) => setDialogState(() => curMapThermals = val),
                              ),
                              SwitchListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                title: const Text('Flight Trail / Breadcrumbs', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                value: curMapTrack,
                                activeThumbColor: Colors.cyanAccent,
                                onChanged: (val) => setDialogState(() => curMapTrack = val),
                              ),
                              SwitchListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                title: const Text('Topographic Contours', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                value: curMapContours,
                                activeThumbColor: Colors.cyanAccent,
                                onChanged: (val) => setDialogState(() => curMapContours = val),
                              ),
                            ],
                          ),
                        ),
                      ] else if (model.type == WidgetType.thermalMap) ...[
                        _buildSectionTitle('Thermal Map Visual Style'),
                        Card(
                          color: Colors.black38,
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _styleChip<ThermalMapStyle>(
                                  label: 'Option 1: XCtrack Bubbles',
                                  value: ThermalMapStyle.xctrackBubbles,
                                  selectedValue: curThermalMapStyle,
                                  onSelected: (val) => setDialogState(() => curThermalMapStyle = val),
                                ),
                                _styleChip<ThermalMapStyle>(
                                  label: 'Option 2: Burnair Core Assist',
                                  value: ThermalMapStyle.burnairCore,
                                  selectedValue: curThermalMapStyle,
                                  onSelected: (val) => setDialogState(() => curThermalMapStyle = val),
                                ),
                                _styleChip<ThermalMapStyle>(
                                  label: 'Option 3: Navigator Ribbon',
                                  value: ThermalMapStyle.navigatorRibbon,
                                  selectedValue: curThermalMapStyle,
                                  onSelected: (val) => setDialogState(() => curThermalMapStyle = val),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildSectionTitle('Thermal Core Display'),
                        Card(
                          color: Colors.black38,
                          child: SwitchListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                            title: const Text('Show Thermal Core Center & Drift', style: TextStyle(color: Colors.white70, fontSize: 13)),
                            subtitle: const Text('Draws estimated lift core centroid with wind vector', style: TextStyle(color: Colors.white38, fontSize: 11)),
                            value: curThermalMapShowCore,
                            activeThumbColor: Colors.cyanAccent,
                            onChanged: (val) => setDialogState(() => curThermalMapShowCore = val),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan.shade700),
                  onPressed: () {
                    final updated = model.copyWith(
                      x: curX,
                      y: curY,
                      w: curW,
                      h: curH,
                      numericStyle: curNumericStyle,
                      windStyle: curWindStyle,
                      varioStyle: curVarioStyle,
                      altitudeChartStyle: curAltitudeChartStyle,
                      mapStyle: curMapStyle,
                      mapOrientation: curMapOrientation,
                      mapShowAirspace: curMapAirspace,
                      mapShowThermals: curMapThermals,
                      mapShowTrack: curMapTrack,
                      mapShowContours: curMapContours,
                      mapZoomLevel: curMapZoomLevel,
                      thermalMapStyle: curThermalMapStyle,
                      thermalMapShowCore: curThermalMapShowCore,
                      thermalMapHistorySeconds: curThermalMapHistorySeconds,
                    );
                    widget.screenManager.updateWidgetPlacement(updated);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Apply', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4, top: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Colors.cyanAccent,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _styleChip<T>({
    required String label,
    required T value,
    required T selectedValue,
    required ValueChanged<T> onSelected,
  }) {
    final isSelected = value == selectedValue;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: Colors.cyan.shade800,
      backgroundColor: Colors.black54,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.white70,
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (sel) {
        if (sel) onSelected(value);
      },
    );
  }
}
