import 'package:flutter/material.dart';
import '../../models/ui_config.dart';
import '../../services/screen_manager_service.dart';
import 'widget_config_dialog.dart';

class WidgetEditFrame extends StatefulWidget {
  const WidgetEditFrame({
    super.key,
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
  State<WidgetEditFrame> createState() => WidgetEditFrameState();
}

class WidgetEditFrameState extends State<WidgetEditFrame> {
  Offset _dragAccum = Offset.zero;
  Offset _resizeAccum = Offset.zero;

  @override
  Widget build(BuildContext context) {
    if (!widget.isEditMode) {
      final isMapOrThermal =
          widget.model.type == WidgetType.map ||
          widget.model.type == WidgetType.thermalMap;
      return Padding(
        padding: isMapOrThermal ? EdgeInsets.zero : const EdgeInsets.all(1.5),
        child: SizedBox.expand(child: widget.child),
      );
    }

    final model = widget.model;
    final id = model.id;
    final isSelected = widget.screenManager.selectedWidgetId == id;
    final typeName = model.type.name.toUpperCase();
    final pixelHeight = model.h * widget.cellHeight;
    final isCompact = model.w <= 2 || pixelHeight < 65;
    final headerHeight = isCompact ? 18.0 : 24.0;
    final bottomBarHeight = isCompact ? 18.0 : 24.0;
    final dragHandleWidth = isCompact ? 20.0 : 26.0;

    return Padding(
      padding: const EdgeInsets.all(2.0),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.screenManager.selectWidget(id),
        child: Container(
          key: Key('widget_box_$id'),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected
                  ? Colors.cyanAccent
                  : Colors.cyanAccent.withAlpha(120),
              width: isSelected ? 2.5 : 1.5,
            ),
            borderRadius: BorderRadius.circular(8),
            color: Colors.blueGrey.shade900.withAlpha(isSelected ? 230 : 200),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: Colors.cyanAccent.withAlpha(120),
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                )
              else
                const BoxShadow(
                  color: Colors.black45,
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
            ],
          ),
          child: Stack(
            children: [
              // Widget Content (Scales to fill allotted frame space)
              if (pixelHeight > (headerHeight + bottomBarHeight + 4))
                Positioned.fill(
                  top: headerHeight + 1,
                  bottom: bottomBarHeight + 1,
                  left: 2,
                  right: 2,
                  child: ClipRect(
                    child: Opacity(
                      opacity: 0.9,
                      child: SizedBox.expand(child: widget.child),
                    ),
                  ),
                ),

              // Top Header: Drag Handle & Info & Actions
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: headerHeight,
                child: Semantics(
                  button: true,
                  label: 'Move widget',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => widget.screenManager.selectWidget(id),
                    onPanStart: (_) {
                      widget.screenManager.selectWidget(id);
                      _dragAccum = Offset.zero;
                    },
                    onPanUpdate: (details) {
                      _dragAccum += details.delta;

                      double accumX = _dragAccum.dx;
                      double accumY = _dragAccum.dy;
                      int dx = 0;
                      int dy = 0;
                      if (accumX > widget.cellWidth * 0.4) {
                        dx = 1;
                        accumX = 0;
                      } else if (accumX < -widget.cellWidth * 0.4) {
                        dx = -1;
                        accumX = 0;
                      }

                      if (accumY > widget.cellHeight * 0.4) {
                        dy = 1;
                        accumY = 0;
                      } else if (accumY < -widget.cellHeight * 0.4) {
                        dy = -1;
                        accumY = 0;
                      }

                      _dragAccum = Offset(accumX, accumY);

                      if (dx != 0 || dy != 0) {
                        widget.screenManager.moveWidget(id, dx, dy);
                      }
                    },
                    child: MouseRegion(
                      cursor: SystemMouseCursors.move,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.cyan.shade900.withAlpha(220),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.drag_indicator,
                                size: isCompact ? 11 : 14,
                                color: Colors.cyanAccent,
                              ),
                              if (model.w > 1) ...[
                                const SizedBox(width: 2),
                                Text(
                                  '$typeName [${model.x},${model.y} ${model.w}x${model.h}]',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isCompact ? 8 : 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(width: 2),
                              ],
                              // Configure Dialog Button
                              IconButton(
                                key: Key('btn_config_$id'),
                                onPressed: () => showWidgetConfigDialog(
                                  context,
                                  widget.model,
                                  widget.screenManager,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 1,
                                ),
                                constraints: const BoxConstraints(),
                                iconSize: isCompact ? 11 : 14,
                                tooltip: 'Configure Widget',
                                icon: const Icon(
                                  Icons.tune,
                                  color: Colors.white70,
                                ),
                              ),
                              // Delete Button
                              IconButton(
                                key: Key('btn_delete_$id'),
                                onPressed: () =>
                                    widget.screenManager.removeWidget(id),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 1,
                                ),
                                constraints: const BoxConstraints(),
                                iconSize: isCompact ? 11 : 14,
                                tooltip: 'Remove Widget',
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom Toolbar: Stepper Resize & Nudge Move Controls
              Positioned(
                bottom: 0,
                left: 0,
                right: dragHandleWidth,
                height: bottomBarHeight,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(6),
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
                              iconSize: isCompact ? 12 : 15,
                              onPressed: () =>
                                  widget.screenManager.moveWidget(id, -1, 0),
                            ),
                            _miniButton(
                              key: Key('btn_move_right_$id'),
                              icon: Icons.chevron_right,
                              tooltip: 'Move Right',
                              enabled: model.x + model.w < 8,
                              iconSize: isCompact ? 12 : 15,
                              onPressed: () =>
                                  widget.screenManager.moveWidget(id, 1, 0),
                            ),
                            _miniButton(
                              key: Key('btn_move_up_$id'),
                              icon: Icons.expand_less,
                              tooltip: 'Move Up',
                              enabled: model.y > 0,
                              iconSize: isCompact ? 12 : 15,
                              onPressed: () =>
                                  widget.screenManager.moveWidget(id, 0, -1),
                            ),
                            _miniButton(
                              key: Key('btn_move_down_$id'),
                              icon: Icons.expand_more,
                              tooltip: 'Move Down',
                              enabled: true,
                              iconSize: isCompact ? 12 : 15,
                              onPressed: () =>
                                  widget.screenManager.moveWidget(id, 0, 1),
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
                              fontSize: isCompact ? 8 : 9,
                              onPressed: () =>
                                  widget.screenManager.resizeWidget(id, -1, 0),
                            ),
                            _textMiniButton(
                              key: Key('btn_inc_width_$id'),
                              label: 'W+',
                              tooltip: 'Increase Width',
                              enabled: model.x + model.w < 8,
                              fontSize: isCompact ? 8 : 9,
                              onPressed: () =>
                                  widget.screenManager.resizeWidget(id, 1, 0),
                            ),
                            const SizedBox(width: 2),
                            // Height dec/inc
                            _textMiniButton(
                              key: Key('btn_dec_height_$id'),
                              label: 'H-',
                              tooltip: 'Decrease Height',
                              enabled: model.h > 1,
                              fontSize: isCompact ? 8 : 9,
                              onPressed: () =>
                                  widget.screenManager.resizeWidget(id, 0, -1),
                            ),
                            _textMiniButton(
                              key: Key('btn_inc_height_$id'),
                              label: 'H+',
                              tooltip: 'Increase Height',
                              enabled: model.h < 16,
                              fontSize: isCompact ? 8 : 9,
                              onPressed: () =>
                                  widget.screenManager.resizeWidget(id, 0, 1),
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
                width: dragHandleWidth,
                height: bottomBarHeight,
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeDownRight,
                  child: Semantics(
                    button: true,
                    label: 'Resize widget',
                    child: GestureDetector(
                      key: Key('resize_handle_$id'),
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (_) {
                        _resizeAccum = Offset.zero;
                      },
                      onPanUpdate: (details) {
                        _resizeAccum += details.delta;

                        double accumX = _resizeAccum.dx;
                        double accumY = _resizeAccum.dy;
                        int dw = 0;
                        int dh = 0;
                        if (accumX > widget.cellWidth * 0.3) {
                          dw = 1;
                          accumX = 0;
                        } else if (accumX < -widget.cellWidth * 0.3) {
                          dw = -1;
                          accumX = 0;
                        }

                        if (accumY > widget.cellHeight * 0.3) {
                          dh = 1;
                          accumY = 0;
                        } else if (accumY < -widget.cellHeight * 0.3) {
                          dh = -1;
                          accumY = 0;
                        }

                        _resizeAccum = Offset(accumX, accumY);

                        if (dw != 0 || dh != 0) {
                          widget.screenManager.resizeWidget(id, dw, dh);
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.cyan.shade900.withAlpha(220),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            bottomRight: Radius.circular(6),
                          ),
                          border: Border.all(
                            color: Colors.cyanAccent.withAlpha(160),
                            width: 1,
                          ),
                        ),
                        child: Tooltip(
                          message: 'Drag corner to resize',
                          child: Center(
                            child: Icon(
                              Icons.south_east,
                              size: isCompact ? 10 : 14,
                              color: Colors.cyanAccent,
                            ),
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
      ),
    );
  }

  Widget _miniButton({
    required Key key,
    required IconData icon,
    required String tooltip,
    required bool enabled,
    required VoidCallback onPressed,
    double iconSize = 15,
  }) {
    return IconButton(
      key: key,
      onPressed: enabled ? onPressed : null,
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      constraints: const BoxConstraints(),
      iconSize: iconSize,
      tooltip: tooltip,
      icon: Icon(icon, color: enabled ? Colors.cyanAccent : Colors.white24),
    );
  }

  Widget _textMiniButton({
    required Key key,
    required String label,
    required String tooltip,
    required bool enabled,
    required VoidCallback onPressed,
    double fontSize = 9,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        key: key,
        onTap: enabled ? onPressed : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
          margin: const EdgeInsets.symmetric(horizontal: 1.0),
          decoration: BoxDecoration(
            color: enabled ? Colors.blueGrey.shade800 : Colors.black45,
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: enabled ? Colors.white : Colors.white24,
            ),
          ),
        ),
      ),
    );
  }

}
