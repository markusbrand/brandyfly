import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../domain/models/size_tier.dart';
import '../../../../domain/models/ui_config.dart';
import '../../../../services/screen_manager_service.dart';
import '../../../core/theme/cockpit_tokens.dart';
import '../view_models/edit_mode_view_model.dart';
import 'widget_config_sheet.dart';

/// Converts accumulated drag distance into whole-cell steps.
///
/// A step is emitted once the accumulated distance crosses [threshold] of a
/// cell; the remainder is kept so slow drags still move.
class CellDragAccumulator {
  CellDragAccumulator({this.threshold = 0.4});

  final double threshold;
  Offset _accum = Offset.zero;

  void reset() => _accum = Offset.zero;

  /// Returns (dx, dy) whole-cell steps for [delta].
  (int, int) add(Offset delta, double cellWidth, double cellHeight) {
    _accum += delta;
    var dx = 0;
    var dy = 0;
    if (cellWidth > 0) {
      final limit = cellWidth * threshold;
      while (_accum.dx > limit) {
        dx++;
        _accum = Offset(_accum.dx - cellWidth, _accum.dy);
      }
      while (_accum.dx < -limit) {
        dx--;
        _accum = Offset(_accum.dx + cellWidth, _accum.dy);
      }
    }
    if (cellHeight > 0) {
      final limit = cellHeight * threshold;
      while (_accum.dy > limit) {
        dy++;
        _accum = Offset(_accum.dx, _accum.dy - cellHeight);
      }
      while (_accum.dy < -limit) {
        dy--;
        _accum = Offset(_accum.dx, _accum.dy + cellHeight);
      }
    }
    return (dx, dy);
  }
}

/// Edit-mode hit area covering one placed widget: tap selects, drag moves in
/// whole grid cells. The widget content beneath ignores pointers while
/// editing, so maps do not pan during layout edits.
class EditHitArea extends StatefulWidget {
  const EditHitArea({
    super.key,
    required this.model,
    required this.editMode,
    required this.cellWidth,
    required this.cellHeight,
    required this.isSelected,
  });

  final WidgetPlacementModel model;
  final EditModeViewModel editMode;
  final double cellWidth;
  final double cellHeight;
  final bool isSelected;

  @override
  State<EditHitArea> createState() => _EditHitAreaState();
}

class _EditHitAreaState extends State<EditHitArea> {
  final CellDragAccumulator _drag = CellDragAccumulator();

  @override
  Widget build(BuildContext context) {
    final id = widget.model.id;
    final vm = widget.editMode;
    return Semantics(
      button: true,
      selected: widget.isSelected,
      label: 'Select ${widget.model.type.displayName} widget',
      child: GestureDetector(
        key: Key('widget_box_$id'),
        behavior: HitTestBehavior.opaque,
        // Count the whole drag from touch-down so the slop is not lost.
        dragStartBehavior: DragStartBehavior.down,
        onTap: () => vm.select(id),
        onPanStart: (_) {
          _drag.reset();
          vm.select(id);
          vm.beginInteraction(id);
        },
        onPanUpdate: (d) {
          final (dx, dy) = _drag.add(
            d.delta,
            widget.cellWidth,
            widget.cellHeight,
          );
          if (dx != 0 || dy != 0) vm.move(id, dx, dy);
        },
        onPanEnd: (_) => vm.endInteraction(),
        onPanCancel: vm.endInteraction,
        child: MouseRegion(
          cursor: SystemMouseCursors.move,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: CockpitTokens.glassCyan.withAlpha(
                  widget.isSelected ? 0 : 110,
                ),
                width: 1,
              ),
              color: CockpitTokens.nightPanel.withAlpha(25),
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

/// Selection chrome drawn above all widgets: outline, size/tier tag with a
/// configure button, and a resize handle placed outside the widget bounds
/// (moved inside when the canvas edge leaves no room). Small widgets never
/// host controls themselves.
class EditSelectionOverlay extends StatefulWidget {
  const EditSelectionOverlay({
    super.key,
    required this.model,
    required this.screenManager,
    required this.cellWidth,
    required this.cellHeight,
    required this.canvasSize,
  });

  final WidgetPlacementModel model;
  final ScreenManagerService screenManager;
  final double cellWidth;
  final double cellHeight;
  final Size canvasSize;

  @override
  State<EditSelectionOverlay> createState() => _EditSelectionOverlayState();
}

class _EditSelectionOverlayState extends State<EditSelectionOverlay> {
  final CellDragAccumulator _resize = CellDragAccumulator();

  static const double _handleHit = 40;
  static const double _handleVisual = 22;
  static const double _tagHeight = 32;

  @override
  Widget build(BuildContext context) {
    final m = widget.model;
    final vm = widget.screenManager.editMode;
    final rect = Rect.fromLTWH(
      m.x * widget.cellWidth,
      m.y * widget.cellHeight,
      m.w * widget.cellWidth,
      m.h * widget.cellHeight,
    );
    final canvas = widget.canvasSize;
    final tier = sizeTierFor(rect.width, rect.height);

    // Handle: outside bottom-right when room, else inside the corner.
    final handleLeft = rect.right + _handleHit <= canvas.width
        ? rect.right - _handleHit / 4
        : rect.right - _handleHit;
    final handleTop = rect.bottom + _handleHit <= canvas.height
        ? rect.bottom - _handleHit / 4
        : rect.bottom - _handleHit;

    // Tag: above when room, else below, else inside the top edge.
    final double tagTop;
    if (rect.top - _tagHeight - 2 >= 0) {
      tagTop = rect.top - _tagHeight - 2;
    } else if (rect.bottom + _tagHeight + 2 <= canvas.height) {
      tagTop = rect.bottom + 2;
    } else {
      tagTop = rect.top + 2;
    }
    // Anchor the tag to the widget edge nearer the canvas center so it never
    // runs off-canvas.
    final anchorRight = rect.center.dx > canvas.width / 2;
    final tagMaxWidth = (anchorRight ? rect.right : canvas.width - rect.left)
        .clamp(0.0, canvas.width);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fromRect(
          rect: rect,
          child: IgnorePointer(
            child: DecoratedBox(
              key: Key('selection_outline_${m.id}'),
              decoration: BoxDecoration(
                border: Border.all(color: CockpitTokens.glassCyan, width: 2.5),
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: CockpitTokens.glassCyan.withAlpha(90),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: anchorRight ? null : rect.left,
          right: anchorRight ? canvas.width - rect.right : null,
          top: tagTop,
          height: _tagHeight,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: tagMaxWidth),
            child: _SizeTag(
              model: m,
              tier: tier,
              onConfigure: () =>
                  showWidgetConfigDialog(context, m, widget.screenManager),
            ),
          ),
        ),
        Positioned(
          left: handleLeft,
          top: handleTop,
          width: _handleHit,
          height: _handleHit,
          child: Semantics(
            button: true,
            label: 'Resize widget',
            child: GestureDetector(
              key: Key('resize_handle_${m.id}'),
              behavior: HitTestBehavior.opaque,
              dragStartBehavior: DragStartBehavior.down,
              onPanStart: (_) {
                _resize.reset();
                vm.beginInteraction(m.id);
              },
              onPanUpdate: (d) {
                final (dw, dh) = _resize.add(
                  d.delta,
                  widget.cellWidth,
                  widget.cellHeight,
                );
                if (dw != 0 || dh != 0) vm.resize(m.id, dw, dh);
              },
              onPanEnd: (_) => vm.endInteraction(),
              onPanCancel: vm.endInteraction,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeDownRight,
                child: Center(
                  child: Container(
                    width: _handleVisual,
                    height: _handleVisual,
                    decoration: BoxDecoration(
                      color: CockpitTokens.bezel,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: CockpitTokens.glassCyan,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.open_in_full,
                      size: 12,
                      color: CockpitTokens.glassCyan,
                    ),
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

class _SizeTag extends StatelessWidget {
  const _SizeTag({
    required this.model,
    required this.tier,
    required this.onConfigure,
  });

  final WidgetPlacementModel model;
  final SizeTier tier;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CockpitTokens.bezel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: const BorderSide(color: CockpitTokens.glassCyan, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                '${model.type.displayName.toUpperCase()} '
                '${model.w}x${model.h} · ${tier.name}',
                key: Key('size_tag_${model.id}'),
                style: CockpitTokens.instrumentLabel.copyWith(
                  color: CockpitTokens.ink,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(
              width: 32,
              height: 32,
              child: IconButton(
                key: Key('btn_config_${model.id}'),
                padding: EdgeInsets.zero,
                iconSize: 16,
                tooltip: 'Configure widget',
                onPressed: onConfigure,
                icon: const Icon(Icons.tune, color: CockpitTokens.glassCyan),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Amber badge marking an interactive widget rendered below 48 dp.
class TouchTargetWarningBadge extends StatelessWidget {
  const TouchTargetWarningBadge({super.key, required this.widgetId});
  final String widgetId;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        key: Key('touch_warning_$widgetId'),
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          color: CockpitTokens.cautionAmber,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.pan_tool_alt, size: 12, color: Colors.black),
      ),
    );
  }
}
