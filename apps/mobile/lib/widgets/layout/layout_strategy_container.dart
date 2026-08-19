import 'dart:math' as math;
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
        final cellHeight = 110.0;

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
              ...screen.widgets.map((widgetModel) {
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
              ...screen.widgets.map((widgetModel) {
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

              ...screen.widgets.map((widgetModel) {
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
    final cfg = screenManager.config;
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
      return Padding(
        padding: const EdgeInsets.all(4.0),
        child: widget.child,
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
            // Widget Content
            Positioned.fill(
              top: 24,
              bottom: 24,
              left: 4,
              right: 4,
              child: ClipRect(
                child: Opacity(
                  opacity: 0.85,
                  child: widget.child,
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

            // Bottom Toolbar: Stepper Resize & Nudge Move Controls
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 24,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(200),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                        const SizedBox(width: 2),
                        // Corner Drag Resize Handle
                        GestureDetector(
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
                            if (_resizeAccumX > widget.cellWidth * 0.4) {
                              dw = 1;
                              _resizeAccumX = 0;
                            } else if (_resizeAccumX < -widget.cellWidth * 0.4) {
                              dw = -1;
                              _resizeAccumX = 0;
                            }

                            if (_resizeAccumY > widget.cellHeight * 0.4) {
                              dh = 1;
                              _resizeAccumY = 0;
                            } else if (_resizeAccumY < -widget.cellHeight * 0.4) {
                              dh = -1;
                              _resizeAccumY = 0;
                            }

                            if (dw != 0 || dh != 0) {
                              widget.screenManager.resizeWidget(id, dw, dh);
                            }
                          },
                          child: const Tooltip(
                            message: 'Resize Handle',
                            child: Icon(
                              Icons.open_in_full,
                              size: 13,
                              color: Colors.amberAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
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

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.blueGrey.shade900,
              title: Text('Configure ${model.type.name.toUpperCase()}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Position X:'),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: curX > 0
                                ? () => setDialogState(() => curX--)
                                : null,
                          ),
                          Text('$curX'),
                          IconButton(
                            icon: const Icon(Icons.add),
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
                      const Text('Position Y:'),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: curY > 0
                                ? () => setDialogState(() => curY--)
                                : null,
                          ),
                          Text('$curY'),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () => setDialogState(() => curY++),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Width:'),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: curW > 1
                                ? () => setDialogState(() => curW--)
                                : null,
                          ),
                          Text('$curW'),
                          IconButton(
                            icon: const Icon(Icons.add),
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
                      const Text('Height:'),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: curH > 1
                                ? () => setDialogState(() => curH--)
                                : null,
                          ),
                          Text('$curH'),
                          IconButton(
                            icon: const Icon(Icons.add),
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
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    widget.screenManager.updateWidgetPlacement(
                      model.copyWith(x: curX, y: curY, w: curW, h: curH),
                    );
                    Navigator.pop(ctx);
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

