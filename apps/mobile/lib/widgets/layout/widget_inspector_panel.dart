import 'package:flutter/material.dart';
import '../../models/ui_config.dart';
import '../../services/screen_manager_service.dart';
import 'widget_config_dialog.dart';

class WidgetInspectorPanel extends StatelessWidget {
  const WidgetInspectorPanel({
    super.key,
    required this.model,
    required this.screenManager,
  });

  final WidgetPlacementModel model;
  final ScreenManagerService screenManager;

  @override
  Widget build(BuildContext context) {
    final id = model.id;
    final typeName = model.type.name.toUpperCase();

    final widgets = screenManager.activeScreen.widgets;
    final currentIndex = widgets.indexWhere((w) => w.id == id);
    final totalWidgets = widgets.length;
    final isAtBottom = currentIndex <= 0;
    final isAtTop = currentIndex == -1 || currentIndex >= totalWidgets - 1;
    final layerNumber = currentIndex != -1 ? (currentIndex + 1) : 1;

    return Container(
      key: const Key('widget_inspector_panel'),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade900.withAlpha(245),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.cyanAccent, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Widget type title & Quick Actions
          Row(
            children: [
              Icon(
                model.type == WidgetType.map
                    ? Icons.map
                    : model.type == WidgetType.thermalMap
                    ? Icons.wb_sunny
                    : Icons.widgets,
                color: Colors.cyanAccent,
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$typeName [${model.x},${model.y} ${model.w}x${model.h}]',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                key: const Key('btn_inspector_config'),
                icon: const Icon(Icons.tune, color: Colors.cyanAccent),
                iconSize: 18,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                tooltip: 'Configure Widget',
                onPressed: () => showWidgetConfigDialog(
                  context,
                  model,
                  screenManager,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                key: const Key('btn_inspector_delete'),
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                iconSize: 18,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                tooltip: 'Remove Widget',
                onPressed: () => screenManager.removeWidget(id),
              ),
              const SizedBox(width: 4),
              IconButton(
                key: const Key('btn_inspector_close'),
                icon: const Icon(Icons.close, color: Colors.white70),
                iconSize: 18,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                tooltip: 'Deselect',
                onPressed: () => screenManager.selectWidget(null),
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 12),
          // Position nudge arrows, size steppers, and stack reordering controls
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                // Move arrows
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _inspectorButton(
                      key: const Key('btn_inspector_move_left'),
                      icon: Icons.chevron_left,
                      tooltip: 'Move Left',
                      enabled: model.x > 0,
                      onPressed: () => screenManager.moveWidget(id, -1, 0),
                    ),
                    _inspectorButton(
                      key: const Key('btn_inspector_move_right'),
                      icon: Icons.chevron_right,
                      tooltip: 'Move Right',
                      enabled: model.x + model.w < 8,
                      onPressed: () => screenManager.moveWidget(id, 1, 0),
                    ),
                    _inspectorButton(
                      key: const Key('btn_inspector_move_up'),
                      icon: Icons.expand_less,
                      tooltip: 'Move Up',
                      enabled: model.y > 0,
                      onPressed: () => screenManager.moveWidget(id, 0, -1),
                    ),
                    _inspectorButton(
                      key: const Key('btn_inspector_move_down'),
                      icon: Icons.expand_more,
                      tooltip: 'Move Down',
                      enabled: true,
                      onPressed: () => screenManager.moveWidget(id, 0, 1),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                // Size steppers
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _inspectorTextButton(
                      key: const Key('btn_inspector_dec_width'),
                      label: 'W-',
                      tooltip: 'Decrease Width',
                      enabled: model.w > 1,
                      onPressed: () => screenManager.resizeWidget(id, -1, 0),
                    ),
                    _inspectorTextButton(
                      key: const Key('btn_inspector_inc_width'),
                      label: 'W+',
                      tooltip: 'Increase Width',
                      enabled: model.x + model.w < 8,
                      onPressed: () => screenManager.resizeWidget(id, 1, 0),
                    ),
                    const SizedBox(width: 4),
                    _inspectorTextButton(
                      key: const Key('btn_inspector_dec_height'),
                      label: 'H-',
                      tooltip: 'Decrease Height',
                      enabled: model.h > 1,
                      onPressed: () => screenManager.resizeWidget(id, 0, -1),
                    ),
                    _inspectorTextButton(
                      key: const Key('btn_inspector_inc_height'),
                      label: 'H+',
                      tooltip: 'Increase Height',
                      enabled: model.h < 16,
                      onPressed: () => screenManager.resizeWidget(id, 0, 1),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                // Stack Layer Reordering Controls
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _inspectorButton(
                      key: const Key('btn_inspector_send_to_back'),
                      icon: Icons.vertical_align_bottom,
                      tooltip: 'Send to Back',
                      enabled: !isAtBottom,
                      onPressed: () => screenManager.sendToBack(id),
                    ),
                    _inspectorButton(
                      key: const Key('btn_inspector_send_backward'),
                      icon: Icons.arrow_downward,
                      tooltip: 'Send Backward',
                      enabled: !isAtBottom,
                      onPressed: () => screenManager.sendBackward(id),
                    ),
                    Container(
                      key: const Key('inspector_layer_badge'),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: Colors.cyan.shade900.withAlpha(140),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.cyanAccent.withAlpha(120),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        'Layer $layerNumber/$totalWidgets',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.cyanAccent,
                        ),
                      ),
                    ),
                    _inspectorButton(
                      key: const Key('btn_inspector_bring_forward'),
                      icon: Icons.arrow_upward,
                      tooltip: 'Bring Forward',
                      enabled: !isAtTop,
                      onPressed: () => screenManager.bringForward(id),
                    ),
                    _inspectorButton(
                      key: const Key('btn_inspector_bring_to_front'),
                      icon: Icons.vertical_align_top,
                      tooltip: 'Bring to Front',
                      enabled: !isAtTop,
                      onPressed: () => screenManager.bringToFront(id),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _inspectorButton({
    required Key key,
    required IconData icon,
    required String tooltip,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      key: key,
      onPressed: enabled ? onPressed : null,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      constraints: const BoxConstraints(),
      iconSize: 18,
      tooltip: tooltip,
      icon: Icon(icon, color: enabled ? Colors.cyanAccent : Colors.white24),
    );
  }

  Widget _inspectorTextButton({
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
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: enabled ? Colors.blueGrey.shade800 : Colors.black45,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: enabled
                  ? Colors.cyanAccent.withAlpha(80)
                  : Colors.transparent,
              width: 0.8,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: enabled ? Colors.white : Colors.white24,
            ),
          ),
        ),
      ),
    );
  }
}
