import 'package:flutter/material.dart';

import '../../../../domain/models/ui_config.dart';
import '../../../../services/screen_manager_service.dart';
import '../../../core/theme/cockpit_tokens.dart';
import 'widget_picker_sheet.dart';

/// Width below which toolbar buttons collapse to icon-only.
const double kToolbarIconOnlyWidth = 360;

/// Bottom edit toolbar: add widget, layer selector, Tall/Wide variant switch
/// and done. Reflows with [Wrap] and collapses labels on narrow canvases
/// instead of scaling down; every control keeps a 48 dp hit target.
class EditToolbar extends StatelessWidget {
  const EditToolbar({
    super.key,
    required this.screenManager,
    required this.widgets,
    required this.selectedWidget,
  });

  final ScreenManagerService screenManager;
  final List<WidgetPlacementModel> widgets;
  final WidgetPlacementModel? selectedWidget;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final iconOnly = constraints.maxWidth < kToolbarIconOnlyWidth;
        return Container(
          key: const Key('edit_toolbar'),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: CockpitTokens.nightPanel.withAlpha(235),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: CockpitTokens.bezelEdge),
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              _ToolbarButton(
                key: const Key('btn_add_widget'),
                icon: Icons.add,
                label: 'Add Widget',
                tooltip: 'Add new widget to layout',
                iconOnly: iconOnly,
                color: Colors.blueAccent,
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.85,
                  ),
                  builder: (ctx) =>
                      WidgetPickerSheet(screenManager: screenManager),
                ),
              ),
              _LayerSelector(
                screenManager: screenManager,
                widgets: widgets,
                selectedWidget: selectedWidget,
                iconOnly: iconOnly,
              ),
              _VariantSwitch(screenManager: screenManager, iconOnly: iconOnly),
              _ToolbarButton(
                key: const Key('btn_done_editing'),
                icon: Icons.check,
                label: 'Done Editing',
                tooltip: 'Save layout and exit edit mode',
                iconOnly: iconOnly,
                color: Colors.green,
                onPressed: () => screenManager.toggleEditMode(false),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    super.key,
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onPressed,
    required this.iconOnly,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback onPressed;
  final bool iconOnly;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final style = FilledButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      minimumSize: const Size(48, 48),
      padding: EdgeInsets.symmetric(horizontal: iconOnly ? 0 : 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    );
    return Tooltip(
      message: tooltip,
      child: iconOnly
          ? FilledButton(
              style: style,
              onPressed: onPressed,
              child: Icon(icon, semanticLabel: label),
            )
          : FilledButton.icon(
              style: style,
              onPressed: onPressed,
              icon: Icon(icon),
              label: Text(label),
            ),
    );
  }
}

class _LayerSelector extends StatelessWidget {
  const _LayerSelector({
    required this.screenManager,
    required this.widgets,
    required this.selectedWidget,
    required this.iconOnly,
  });

  final ScreenManagerService screenManager;
  final List<WidgetPlacementModel> widgets;
  final WidgetPlacementModel? selectedWidget;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final selected = selectedWidget;
    return PopupMenuButton<String>(
      key: const Key('btn_layer_selector'),
      tooltip: 'Select Widget Layer',
      color: Colors.blueGrey.shade900,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: CockpitTokens.glassCyan, width: 1.2),
      ),
      onSelected: screenManager.selectWidget,
      itemBuilder: (ctx) => [
        for (final w in widgets.reversed)
          PopupMenuItem<String>(
            key: Key('layer_item_${w.id}'),
            value: w.id,
            child: Row(
              children: [
                Icon(
                  w.type == WidgetType.map
                      ? Icons.map
                      : w.type == WidgetType.thermalMap
                      ? Icons.wb_sunny
                      : w.type.isMapControl
                      ? Icons.control_camera
                      : Icons.widgets,
                  color: w.id == selected?.id
                      ? CockpitTokens.glassCyan
                      : Colors.white70,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${w.type.name.toUpperCase()} (${w.w}x${w.h} @ ${w.x},${w.y})',
                    style: TextStyle(
                      color: w.id == selected?.id
                          ? CockpitTokens.glassCyan
                          : Colors.white,
                      fontWeight: w.id == selected?.id
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (w.id == selected?.id)
                  const Icon(
                    Icons.check,
                    color: CockpitTokens.glassCyan,
                    size: 14,
                  ),
              ],
            ),
          ),
      ],
      child: Container(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.blueGrey.shade900.withAlpha(230),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected != null ? CockpitTokens.glassCyan : Colors.white30,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.layers,
              size: 18,
              color: selected != null
                  ? CockpitTokens.glassCyan
                  : Colors.white70,
            ),
            if (!iconOnly) ...[
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 110),
                child: Text(
                  selected != null
                      ? selected.type.displayName
                      : 'Layers (${widgets.length})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected != null
                        ? CockpitTokens.glassCyan
                        : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_drop_down,
                color: Colors.white70,
                size: 18,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tall / Wide layout variant switch. Selecting Wide on a screen without a
/// wide variant offers to copy the tall layout.
class _VariantSwitch extends StatelessWidget {
  const _VariantSwitch({required this.screenManager, required this.iconOnly});

  final ScreenManagerService screenManager;
  final bool iconOnly;

  Future<void> _selectWide(BuildContext context) async {
    final vm = screenManager.editMode;
    if (vm.setEditedVariant(LayoutVariant.wide)) return;
    final create = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create wide layout?'),
        content: const Text(
          'Wide screens (landscape, tablets) currently show the tall layout '
          'stretched. Copy the tall layout as a starting point for a '
          'separate wide layout?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('btn_copy_from_tall'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Copy from Tall'),
          ),
        ],
      ),
    );
    if (create == true) vm.createWideFromTall();
  }

  @override
  Widget build(BuildContext context) {
    final vm = screenManager.editMode;
    final variant = vm.editedVariant;
    final hasWide = vm.activeScreen.hasWideVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SegmentedButton<LayoutVariant>(
          key: const Key('variant_switch'),
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(
            minimumSize: const Size(48, 48),
            selectedBackgroundColor: CockpitTokens.glassCyan.withAlpha(70),
          ),
          segments: [
            ButtonSegment(
              value: LayoutVariant.tall,
              icon: const Icon(
                Icons.stay_current_portrait,
                size: 18,
                key: Key('btn_variant_tall'),
              ),
              label: iconOnly ? null : const Text('Tall'),
              tooltip: 'Edit tall layout',
            ),
            ButtonSegment(
              value: LayoutVariant.wide,
              icon: const Icon(
                Icons.stay_current_landscape,
                size: 18,
                key: Key('btn_variant_wide'),
              ),
              label: iconOnly ? null : const Text('Wide'),
              tooltip: hasWide ? 'Edit wide layout' : 'Create wide layout',
            ),
          ],
          selected: {variant},
          onSelectionChanged: (s) {
            if (s.first == LayoutVariant.wide) {
              _selectWide(context);
            } else {
              vm.setEditedVariant(LayoutVariant.tall);
            }
          },
        ),
        if (hasWide && variant == LayoutVariant.wide)
          IconButton(
            key: const Key('btn_variant_delete_wide'),
            tooltip: 'Delete wide layout',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(Icons.delete_sweep, color: CockpitTokens.sinkRed),
            onPressed: vm.deleteWideVariant,
          ),
      ],
    );
  }
}
