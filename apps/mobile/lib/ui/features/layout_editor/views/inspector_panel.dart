import 'package:flutter/material.dart';

import '../../../../domain/models/size_tier.dart';
import '../../../../domain/models/ui_config.dart';
import '../../../../domain/models/widget_catalog.dart';
import '../../../../services/screen_manager_service.dart';
import '../../../core/rebuild_probe.dart';
import '../../../core/theme/cockpit_tokens.dart';
import 'widget_config_sheet.dart';

/// Width below which inspector controls collapse to icon-only buttons.
const double kInspectorIconOnlyWidth = 360;

/// Width below which the inspector shows one control group at a time
/// (tabbed) instead of all groups.
const double kInspectorTabbedWidth = 600;

/// Control groups of the inspector.
enum InspectorSection { size, resize, move, layer }

extension on InspectorSection {
  String get label {
    switch (this) {
      case InspectorSection.size:
        return 'Size';
      case InspectorSection.resize:
        return 'Resize';
      case InspectorSection.move:
        return 'Move';
      case InspectorSection.layer:
        return 'Layer';
    }
  }
}

/// Docked inspector for the selected widget: presets, nudge and size
/// steppers, stack order, configure, remove and touch-target fix.
///
/// Controls reflow with [Wrap] instead of being scaled down, and every control
/// keeps a 48x48 dp hit target.
class WidgetInspectorPanel extends StatefulWidget {
  const WidgetInspectorPanel({
    super.key,
    required this.model,
    required this.screenManager,
  });

  final WidgetPlacementModel model;
  final ScreenManagerService screenManager;

  @override
  State<WidgetInspectorPanel> createState() => _WidgetInspectorPanelState();
}

class _WidgetInspectorPanelState extends State<WidgetInspectorPanel> {
  InspectorSection _section = InspectorSection.size;

  @override
  Widget build(BuildContext context) {
    RebuildProbe.tick('inspector');
    final model = widget.model;
    final screenManager = widget.screenManager;
    final id = model.id;
    final vm = screenManager.editMode;
    final widgets = vm.editedWidgets;
    final currentIndex = widgets.indexWhere((w) => w.id == id);
    final totalWidgets = widgets.length;
    final isAtBottom = currentIndex <= 0;
    final isAtTop = currentIndex == -1 || currentIndex >= totalWidgets - 1;
    final layerNumber = currentIndex != -1 ? (currentIndex + 1) : 1;
    final spec = specFor(model.type);
    final geometry = vm.geometry;
    final tier = geometry.isKnown
        ? sizeTierFor(
            model.w * geometry.cellWidth,
            model.h * geometry.cellHeight,
          )
        : null;
    final belowTouch = vm.isBelowTouchTarget(model);
    final min = effectiveMinSize(
      model.type,
      geometry: geometry.isKnown ? geometry : null,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final iconOnly = constraints.maxWidth < kInspectorIconOnlyWidth;
        final tabbed = constraints.maxWidth < kInspectorTabbedWidth;
        final sizeGroup = <Widget>[
          for (final preset in SizePreset.values)
            if (spec.presets.containsKey(preset))
              _InspectorText(
                key: Key('btn_inspector_preset_${preset.name}'),
                label: preset.label,
                tooltip: 'Size ${preset.label} (${spec.presets[preset]})',
                selected: spec.presets[preset] == GridSize(model.w, model.h),
                onPressed: () => screenManager.applySizePreset(id, preset),
              ),
        ];
        final moveGroup = <Widget>[
          _InspectorIcon(
            buttonKey: const Key('btn_inspector_move_left'),
            icon: Icons.chevron_left,
            tooltip: 'Move Left',
            onPressed: model.x > 0
                ? () => screenManager.moveWidget(id, -1, 0)
                : null,
          ),
          _InspectorIcon(
            buttonKey: const Key('btn_inspector_move_right'),
            icon: Icons.chevron_right,
            tooltip: 'Move Right',
            onPressed: model.x + model.w < GridSpec.columns
                ? () => screenManager.moveWidget(id, 1, 0)
                : null,
          ),
          _InspectorIcon(
            buttonKey: const Key('btn_inspector_move_up'),
            icon: Icons.expand_less,
            tooltip: 'Move Up',
            onPressed: model.y > 0
                ? () => screenManager.moveWidget(id, 0, -1)
                : null,
          ),
          _InspectorIcon(
            buttonKey: const Key('btn_inspector_move_down'),
            icon: Icons.expand_more,
            tooltip: 'Move Down',
            onPressed: model.y + model.h < GridSpec.rows
                ? () => screenManager.moveWidget(id, 0, 1)
                : null,
          ),
        ];
        final resizeGroup = <Widget>[
          _InspectorText(
            key: const Key('btn_inspector_dec_width'),
            label: 'W-',
            icon: Icons.compress,
            iconOnly: iconOnly,
            tooltip: 'Decrease Width',
            onPressed: model.w > min.w
                ? () => screenManager.resizeWidget(id, -1, 0)
                : null,
          ),
          _InspectorText(
            key: const Key('btn_inspector_inc_width'),
            label: 'W+',
            icon: Icons.expand,
            iconOnly: iconOnly,
            tooltip: 'Increase Width',
            onPressed: model.x + model.w < GridSpec.columns
                ? () => screenManager.resizeWidget(id, 1, 0)
                : null,
          ),
          _InspectorText(
            key: const Key('btn_inspector_dec_height'),
            label: 'H-',
            icon: Icons.unfold_less,
            iconOnly: iconOnly,
            tooltip: 'Decrease Height',
            onPressed: model.h > min.h
                ? () => screenManager.resizeWidget(id, 0, -1)
                : null,
          ),
          _InspectorText(
            key: const Key('btn_inspector_inc_height'),
            label: 'H+',
            icon: Icons.unfold_more,
            iconOnly: iconOnly,
            tooltip: 'Increase Height',
            onPressed: model.y + model.h < GridSpec.rows
                ? () => screenManager.resizeWidget(id, 0, 1)
                : null,
          ),
        ];
        final layerGroup = <Widget>[
          _InspectorIcon(
            buttonKey: const Key('btn_inspector_send_to_back'),
            icon: Icons.vertical_align_bottom,
            tooltip: 'Send to Back',
            onPressed: isAtBottom ? null : () => screenManager.sendToBack(id),
          ),
          _InspectorIcon(
            buttonKey: const Key('btn_inspector_send_backward'),
            icon: Icons.arrow_downward,
            tooltip: 'Send Backward',
            onPressed: isAtBottom ? null : () => screenManager.sendBackward(id),
          ),
          _Badge(
            key: const Key('inspector_layer_badge'),
            text: 'Layer $layerNumber/$totalWidgets',
          ),
          _InspectorIcon(
            buttonKey: const Key('btn_inspector_bring_forward'),
            icon: Icons.arrow_upward,
            tooltip: 'Bring Forward',
            onPressed: isAtTop ? null : () => screenManager.bringForward(id),
          ),
          _InspectorIcon(
            buttonKey: const Key('btn_inspector_bring_to_front'),
            icon: Icons.vertical_align_top,
            tooltip: 'Bring to Front',
            onPressed: isAtTop ? null : () => screenManager.bringToFront(id),
          ),
        ];
        return Container(
          key: const Key('widget_inspector_panel'),
          decoration: BoxDecoration(
            color: CockpitTokens.bezel.withAlpha(245),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: CockpitTokens.glassCyan, width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    model.type.isMapLike
                        ? Icons.map
                        : model.type.isMapControl
                        ? Icons.control_camera
                        : Icons.widgets,
                    color: CockpitTokens.glassCyan,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${model.type.displayName.toUpperCase()} '
                      '[${model.x},${model.y} ${model.w}x${model.h}]',
                      style: const TextStyle(
                        color: CockpitTokens.ink,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (tier != null)
                    _Badge(
                      key: const Key('inspector_tier_badge'),
                      text: tier.name,
                    ),
                  _InspectorIcon(
                    buttonKey: const Key('btn_inspector_config'),
                    icon: Icons.tune,
                    tooltip: 'Configure Widget',
                    onPressed: () =>
                        showWidgetConfigDialog(context, model, screenManager),
                  ),
                  _InspectorIcon(
                    buttonKey: const Key('btn_inspector_delete'),
                    icon: Icons.delete_outline,
                    tooltip: 'Remove Widget',
                    color: CockpitTokens.sinkRed,
                    onPressed: () => screenManager.removeWidget(id),
                  ),
                  _InspectorIcon(
                    buttonKey: const Key('btn_inspector_close'),
                    icon: Icons.close,
                    tooltip: 'Deselect',
                    color: CockpitTokens.inkMuted,
                    onPressed: () => screenManager.selectWidget(null),
                  ),
                ],
              ),
              if (belowTouch)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: CockpitTokens.cautionAmber,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'Smaller than a 48 dp touch target on this screen',
                          style: TextStyle(
                            color: CockpitTokens.cautionAmber,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      TextButton(
                        key: const Key('btn_inspector_fix_size'),
                        onPressed: () => vm.fixTouchSize(id),
                        child: const Text('Fix size'),
                      ),
                    ],
                  ),
                ),
              const Divider(color: Colors.white24, height: 4),
              if (tabbed) ...[
                _SectionTabs(
                  selected: _section,
                  onSelected: (s) => setState(() => _section = s),
                ),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 2,
                  children: switch (_section) {
                    InspectorSection.size => sizeGroup,
                    InspectorSection.resize => resizeGroup,
                    InspectorSection.move => moveGroup,
                    InspectorSection.layer => layerGroup,
                  },
                ),
              ] else
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 2,
                  children: [
                    ...sizeGroup,
                    const _GroupGap(),
                    ...resizeGroup,
                    const _GroupGap(),
                    ...moveGroup,
                    const _GroupGap(),
                    ...layerGroup,
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionTabs extends StatelessWidget {
  const _SectionTabs({required this.selected, required this.onSelected});

  final InspectorSection selected;
  final ValueChanged<InspectorSection> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final section in InspectorSection.values)
          Expanded(
            child: InkWell(
              key: Key('inspector_tab_${section.name}'),
              onTap: () => onSelected(section),
              child: SizedBox(
                height: 40,
                child: Center(
                  child: Text(
                    section.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.4,
                      color: section == selected
                          ? CockpitTokens.glassCyan
                          : CockpitTokens.inkMuted,
                      decoration: section == selected
                          ? TextDecoration.underline
                          : null,
                      decorationColor: CockpitTokens.glassCyan,
                      decorationThickness: 2,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _GroupGap extends StatelessWidget {
  const _GroupGap();
  @override
  Widget build(BuildContext context) => const SizedBox(width: 6, height: 48);
}

class _Badge extends StatelessWidget {
  const _Badge({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: Colors.cyan.shade900.withAlpha(140),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: CockpitTokens.glassCyan.withAlpha(120),
          width: 0.8,
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: CockpitTokens.glassCyan,
        ),
      ),
    );
  }
}

class _InspectorIcon extends StatelessWidget {
  const _InspectorIcon({
    required this.buttonKey,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color = CockpitTokens.glassCyan,
  });

  /// Key placed on the [IconButton] itself so tests can inspect `onPressed`.
  final Key buttonKey;
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: buttonKey,
      onPressed: onPressed,
      iconSize: 20,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      tooltip: tooltip,
      icon: Icon(icon, color: onPressed != null ? color : Colors.white24),
    );
  }
}

class _InspectorText extends StatelessWidget {
  const _InspectorText({
    super.key,
    required this.label,
    required this.tooltip,
    required this.onPressed,
    this.icon,
    this.iconOnly = false,
    this.selected = false,
  });

  final String label;
  final String tooltip;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool iconOnly;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final showIcon = iconOnly && icon != null;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: selected
                    ? CockpitTokens.glassCyan.withAlpha(60)
                    : enabled
                    ? Colors.blueGrey.shade800
                    : Colors.black45,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: selected
                      ? CockpitTokens.glassCyan
                      : enabled
                      ? CockpitTokens.glassCyan.withAlpha(80)
                      : Colors.transparent,
                  width: 0.8,
                ),
              ),
              child: showIcon
                  ? Icon(
                      icon,
                      size: 16,
                      color: enabled ? CockpitTokens.ink : Colors.white24,
                    )
                  : Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: enabled ? CockpitTokens.ink : Colors.white24,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
