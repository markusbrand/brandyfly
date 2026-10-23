import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../data/repositories/telemetry_repository.dart';
import '../../../../domain/models/cockpit_telemetry.dart';
import '../../../../domain/models/size_tier.dart';
import '../../../../domain/models/ui_config.dart';
import '../../../../services/screen_manager_service.dart';
import '../../../core/rebuild_probe.dart';
import '../../../core/theme/cockpit_tokens.dart';
import '../../../core/widgets/draggable_overlay_container.dart';
import '../../layout_editor/view_models/edit_mode_view_model.dart';
import '../../../../services/airspace_service.dart';
import '../../../../widgets/flight/airspace_warning_banner_hud.dart';
import '../../layout_editor/views/edit_frame.dart';
import '../../layout_editor/views/edit_toolbar.dart';
import '../../layout_editor/views/inspector_panel.dart';
import '../../layout_editor/views/widget_picker_sheet.dart';
import '../../map/view_models/map_camera_view_model.dart';
import '../view_models/flight_canvas_view_model.dart';
import 'grid_guide_painter.dart';
import 'strategy_backdrop.dart';
import 'widget_slot.dart';

/// Fallback canvas height used when the parent provides unbounded height.
const double kUnboundedCanvasFallbackHeight = 600.0;

/// Canvas width above which edit chrome is constrained to [kEditChromeMaxWidth].
const double kWideCanvasBreakpoint = 840.0;
const double kEditChromeMaxWidth = 560.0;

/// Minimum width of a wide canvas for docking edit chrome as a side panel.
const double kSideDockMinWidth = 600.0;

/// Full-screen flight canvas: renders the active screen on the fixed 16x32
/// grid (no scrolling), picks the tall or wide layout variant from the
/// available space, and hosts edit-mode chrome.
///
/// Telemetry is consumed through a [ValueListenable] so that a telemetry tick
/// rebuilds only the instruments whose displayed fields changed; the canvas
/// itself rebuilds only on layout / edit-state changes. The legacy
/// [telemetryData] map is still accepted and adapted internally.
class LayoutStrategyContainer extends StatefulWidget {
  const LayoutStrategyContainer({
    super.key,
    required this.screenManager,
    this.telemetryData,
    this.telemetry,
  });

  final ScreenManagerService screenManager;

  /// Legacy untyped telemetry; converted to [CockpitTelemetry].
  final Map<String, dynamic>? telemetryData;

  /// Typed telemetry stream (preferred). Falls back to a [TelemetryRepository]
  /// provided above this widget, then to [telemetryData] / defaults.
  final ValueListenable<CockpitTelemetry>? telemetry;

  @override
  State<LayoutStrategyContainer> createState() =>
      _LayoutStrategyContainerState();
}

class _LayoutStrategyContainerState extends State<LayoutStrategyContainer> {
  final ValueNotifier<CockpitTelemetry> _legacyTelemetry =
      ValueNotifier<CockpitTelemetry>(const CockpitTelemetry());
  final MapCameraRegistry _cameraRegistry = MapCameraRegistry();
  final FlightCanvasViewModel _canvasViewModel = FlightCanvasViewModel();
  Offset? _manualDockOffset;
  bool _isEditDockMinimized = false;

  @override
  void initState() {
    super.initState();
    _syncLegacyTelemetry();
  }

  @override
  void didUpdateWidget(covariant LayoutStrategyContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.telemetryData, widget.telemetryData)) {
      _syncLegacyTelemetry();
    }
  }

  void _syncLegacyTelemetry() {
    final data = widget.telemetryData;
    if (data != null) {
      _legacyTelemetry.value = CockpitTelemetry.fromMap(data);
    }
  }

  ValueListenable<CockpitTelemetry> _resolveTelemetry(BuildContext context) {
    final explicit = widget.telemetry;
    if (explicit != null) return explicit;
    if (widget.telemetryData == null) {
      final repo = Provider.of<TelemetryRepository?>(context, listen: false);
      if (repo != null) return repo.telemetry;
    }
    return _legacyTelemetry;
  }

  @override
  void dispose() {
    _legacyTelemetry.dispose();
    _cameraRegistry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final telemetry = _resolveTelemetry(context);
    final editMode = widget.screenManager.editMode;
    return MapCameraScope(
      registry: _cameraRegistry,
      child: ListenableBuilder(
        listenable: editMode,
        builder: (context, _) {
          RebuildProbe.tick('canvas');
          return LayoutBuilder(
            builder: (context, constraints) =>
                _buildCanvas(context, constraints, editMode, telemetry),
          );
        },
      ),
    );
  }

  Widget _buildCanvas(
    BuildContext context,
    BoxConstraints constraints,
    EditModeViewModel editMode,
    ValueListenable<CockpitTelemetry> telemetry,
  ) {
    final outerWidth = constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : MediaQuery.sizeOf(context).width;
    final outerHeight = constraints.maxHeight.isFinite
        ? constraints.maxHeight
        : kUnboundedCanvasFallbackHeight;
    if (outerWidth <= 0 || outerHeight <= 0) {
      return const SizedBox.shrink();
    }

    final shape = canvasShapeFor(outerWidth, outerHeight);
    final isEditMode = editMode.isEditMode;
    if (!isEditMode) {
      _manualDockOffset = null;
      _isEditDockMinimized = false;
    }
    final state = _canvasViewModel.resolve(
      screen: editMode.activeScreen,
      shape: shape,
      isEditMode: isEditMode,
      editedVariant: editMode.editedVariant,
    );

    // Letterboxed preview when editing the variant not shown on this canvas.
    var canvasWidth = outerWidth;
    var canvasHeight = outerHeight;
    if (state.letterboxed) {
      final aspect = state.variant == LayoutVariant.wide ? 16 / 9 : 9 / 16;
      if (outerWidth / outerHeight > aspect) {
        canvasWidth = outerHeight * aspect;
      } else {
        canvasHeight = outerWidth / aspect;
      }
    }
    final cellWidth = canvasWidth / GridSpec.columns;
    final cellHeight = canvasHeight / GridSpec.rows;
    final geometry = CellGeometry(cellWidth, cellHeight);
    editMode.reportCanvas(shape, geometry);

    final selectedId = isEditMode ? editMode.selectedWidgetId : null;
    final ordered = _orderedWidgets(state.widgets, selectedId);
    WidgetPlacementModel? selected;
    if (selectedId != null) {
      for (final w in state.widgets) {
        if (w.id == selectedId) selected = w;
      }
    }

    final canvas = SizedBox(
      key: const Key('flight_canvas'),
      width: canvasWidth,
      height: canvasHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: StrategyBackdrop(
              strategy: state.screen.layoutStrategy,
              isEditMode: isEditMode,
              cellWidth: cellWidth,
            ),
          ),
          if (isEditMode)
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    key: const Key('edit_grid_layer'),
                    painter: GridPainter(
                      cellWidth: cellWidth,
                      cellHeight: cellHeight,
                    ),
                  ),
                ),
              ),
            ),
          for (final model in ordered)
            Positioned(
              key: Key('positioned_${model.id}'),
              left: model.x * cellWidth,
              top: model.y * cellHeight,
              width: model.w * cellWidth,
              height: model.h * cellHeight,
              child: _PlacedWidget(
                model: model,
                state: state,
                telemetry: telemetry,
                editMode: editMode,
                isEditMode: isEditMode,
                isSelected: model.id == selectedId,
                cellWidth: cellWidth,
                cellHeight: cellHeight,
              ),
            ),
          if (isEditMode) ...[
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: ValueListenableBuilder(
                    valueListenable: editMode.guides,
                    builder: (context, result, _) => CustomPaint(
                      key: const Key('edit_guide_layer'),
                      painter: GuidePainter(
                        cellWidth: cellWidth,
                        cellHeight: cellHeight,
                        result: result,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            for (final model in state.widgets)
              if (editMode.isBelowTouchTarget(model))
                Positioned(
                  left: (model.x + model.w) * cellWidth - 18,
                  top: model.y * cellHeight + 2,
                  child: TouchTargetWarningBadge(widgetId: model.id),
                ),
            if (selected != null)
              Positioned.fill(
                child: EditSelectionOverlay(
                  model: selected,
                  screenManager: widget.screenManager,
                  cellWidth: cellWidth,
                  cellHeight: cellHeight,
                  canvasSize: Size(canvasWidth, canvasHeight),
                ),
              ),
          ],
          if (!isEditMode)
            Positioned(
              top: 8,
              left: 16,
              right: 16,
              child: Consumer<AirspaceService?>(
                builder: (context, airspace, _) {
                  if (airspace == null) return const SizedBox.shrink();
                  return AirspaceWarningBannerHUD(
                    proximity: airspace.latestProximity,
                  );
                },
              ),
            ),
        ],
      ),
    );

    Widget body = state.letterboxed
        ? ColoredBox(
            key: const Key('letterbox_preview'),
            color: CockpitTokens.nightPanel,
            child: Center(child: canvas),
          )
        : canvas;

    if (isEditMode) {
      body = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => editMode.select(null),
        child: body,
      );
    }

    return SizedBox(
      width: outerWidth,
      height: outerHeight,
      child: Stack(
        children: [
          Positioned.fill(child: body),
          if (isEditMode)
            ..._buildEditDock(
              outerSize: Size(outerWidth, outerHeight),
              canvasOffset: Offset(
                (outerWidth - canvasWidth) / 2,
                (outerHeight - canvasHeight) / 2,
              ),
              cellWidth: cellWidth,
              cellHeight: cellHeight,
              state: state,
              selected: selected,
            ),
        ],
      ),
    );
  }

  /// Unified Edit Mode Dock combining [WidgetInspectorPanel] and [EditToolbar]
  /// with auto-dodge positioning, manual 2D drag override, reset, and minimize pill.
  List<Widget> _buildEditDock({
    required Size outerSize,
    required Offset canvasOffset,
    required double cellWidth,
    required double cellHeight,
    required CanvasLayoutState state,
    required WidgetPlacementModel? selected,
  }) {
    return [
      _EditDockOverlay(
        screenManager: widget.screenManager,
        outerSize: outerSize,
        canvasOffset: canvasOffset,
        cellWidth: cellWidth,
        cellHeight: cellHeight,
        state: state,
        selected: selected,
        manualOffset: _manualDockOffset,
        isMinimized: _isEditDockMinimized,
        onManualOffsetChanged: (offset) {
          setState(() {
            _manualDockOffset = offset;
          });
        },
        onResetAutoDodge: () {
          setState(() {
            _manualDockOffset = null;
          });
        },
        onToggleMinimized: (minimized) {
          setState(() {
            _isEditDockMinimized = minimized;
          });
        },
      ),
    ];
  }

  /// Persistent stack order; the selected widget is temporarily elevated to
  /// the foreground while editing.
  List<WidgetPlacementModel> _orderedWidgets(
    List<WidgetPlacementModel> widgets,
    String? selectedId,
  ) {
    if (selectedId == null) return widgets;
    final index = widgets.indexWhere((w) => w.id == selectedId);
    if (index == -1 || index == widgets.length - 1) return widgets;
    return [...widgets]
      ..removeAt(index)
      ..add(widgets[index]);
  }
}

class _EditDockOverlay extends StatelessWidget {
  const _EditDockOverlay({
    required this.screenManager,
    required this.outerSize,
    required this.canvasOffset,
    required this.cellWidth,
    required this.cellHeight,
    required this.state,
    required this.selected,
    required this.manualOffset,
    required this.isMinimized,
    required this.onManualOffsetChanged,
    required this.onResetAutoDodge,
    required this.onToggleMinimized,
  });

  final ScreenManagerService screenManager;
  final Size outerSize;
  final Offset canvasOffset;
  final double cellWidth;
  final double cellHeight;
  final CanvasLayoutState state;
  final WidgetPlacementModel? selected;
  final Offset? manualOffset;
  final bool isMinimized;
  final ValueChanged<Offset> onManualOffsetChanged;
  final VoidCallback onResetAutoDodge;
  final ValueChanged<bool> onToggleMinimized;

  @override
  Widget build(BuildContext context) {
    final selectedCenter = selected == null
        ? null
        : canvasOffset +
            Offset(
              (selected!.x + selected!.w / 2) * cellWidth,
              (selected!.y + selected!.h / 2) * cellHeight,
            );

    final isWideSideDock =
        outerSize.width > outerSize.height &&
        outerSize.width >= kSideDockMinWidth;

    Alignment initialAlignment;
    double dockWidth;

    if (isWideSideDock) {
      final dockLeft =
          selectedCenter != null && selectedCenter.dx > outerSize.width / 2;
      initialAlignment =
          dockLeft ? Alignment.bottomLeft : Alignment.bottomRight;
      dockWidth = math.min(
        kEditChromeMaxWidth,
        math.max(320.0, outerSize.width * 0.42),
      );
    } else {
      final inspectorOnTop =
          selectedCenter != null && selectedCenter.dy > outerSize.height / 2;
      initialAlignment =
          inspectorOnTop ? Alignment.topCenter : Alignment.bottomCenter;
      dockWidth = outerSize.width > kWideCanvasBreakpoint
          ? kEditChromeMaxWidth
          : (outerSize.width - 16);
    }

    return DraggableOverlayContainer(
      cardKey: const Key('edit_dock_overlay'),
      semanticsLabel: 'Move edit mode dock',
      initialAlignment: initialAlignment,
      position: manualOffset,
      margin: const EdgeInsets.all(8),
      onPositionChanged: onManualOffsetChanged,
      child: SizedBox(
        width: isMinimized ? math.min(dockWidth, 340.0) : dockWidth,
        child: isMinimized
            ? _buildMinimizedPill(context)
            : _buildExpandedDock(context, isWideSideDock),
      ),
    );
  }

  Widget _buildMinimizedPill(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: CockpitTokens.nightPanel.withAlpha(240),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: CockpitTokens.bezelEdge, width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              key: const Key('edit_dock_drag_handle'),
              width: 24,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white38,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Editing',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              key: const Key('btn_add_widget'),
              icon: const Icon(Icons.add, size: 18, color: Colors.blueAccent),
              tooltip: 'Add Widget',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
            if (manualOffset != null)
              IconButton(
                key: const Key('btn_edit_dock_auto_dodge'),
                icon: const Icon(
                  Icons.auto_awesome,
                  size: 16,
                  color: Colors.cyanAccent,
                ),
                tooltip: 'Reset to auto-dodge',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: onResetAutoDodge,
              ),
            IconButton(
              key: const Key('btn_edit_dock_expand'),
              icon: const Icon(
                Icons.expand_less,
                size: 20,
                color: Colors.cyanAccent,
              ),
              tooltip: 'Expand dock',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: () => onToggleMinimized(false),
            ),
            IconButton(
              key: const Key('btn_done_editing'),
              icon: const Icon(Icons.check, size: 18, color: Colors.green),
              tooltip: 'Done Editing',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: () => screenManager.toggleEditMode(false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedDock(BuildContext context, bool isWideSideDock) {
    final inspector = selected == null
        ? null
        : WidgetInspectorPanel(
            model: selected!,
            screenManager: screenManager,
          );
    final toolbar = EditToolbar(
      screenManager: screenManager,
      widgets: state.widgets,
      selectedWidget: selected,
    );

    final header = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Row(
        children: [
          const Text(
            'EDIT DOCK',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          Expanded(
            child: Center(
              child: Container(
                key: const Key('edit_dock_drag_handle'),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white38,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          if (manualOffset != null)
            IconButton(
              key: const Key('btn_edit_dock_auto_dodge'),
              icon: const Icon(
                Icons.auto_awesome,
                size: 16,
                color: Colors.cyanAccent,
              ),
              tooltip: 'Reset to auto-dodge',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: onResetAutoDodge,
            ),
          IconButton(
            key: const Key('btn_edit_dock_minimize'),
            icon: const Icon(
              Icons.expand_more,
              size: 20,
              color: Colors.white70,
            ),
            tooltip: 'Minimize dock',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: () => onToggleMinimized(true),
          ),
        ],
      ),
    );

    final maxInspectorHeight = math.max(120.0, outerSize.height - 120.0);
    final needScroll = isWideSideDock || outerSize.height < 450;

    return Material(
      type: MaterialType.transparency,
      child: Container(
        decoration: BoxDecoration(
          color: CockpitTokens.nightPanel.withAlpha(240),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: CockpitTokens.bezelEdge, width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            if (inspector != null) ...[
              if (needScroll)
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxInspectorHeight),
                  child: SingleChildScrollView(child: inspector),
                )
              else
                inspector,
              const SizedBox(height: 4),
            ],
            toolbar,
          ],
        ),
      ),
    );
  }
}

/// One placed widget. The child structure is stable between flight and edit
/// mode so stateful content (e.g. the map camera) survives toggling edit mode.
class _PlacedWidget extends StatelessWidget {
  const _PlacedWidget({
    required this.model,
    required this.state,
    required this.telemetry,
    required this.editMode,
    required this.isEditMode,
    required this.isSelected,
    required this.cellWidth,
    required this.cellHeight,
  });

  final WidgetPlacementModel model;
  final CanvasLayoutState state;
  final ValueListenable<CockpitTelemetry> telemetry;
  final EditModeViewModel editMode;
  final bool isEditMode;
  final bool isSelected;
  final double cellWidth;
  final double cellHeight;

  @override
  Widget build(BuildContext context) {
    final edgeToEdge = model.type.isMapLike;
    final inset = edgeToEdge ? 0.0 : 1.5;
    final width = math.max(0.0, model.w * cellWidth - inset * 2);
    final height = math.max(0.0, model.h * cellHeight - inset * 2);
    final tier = sizeTierFor(width, height);

    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.all(inset),
            child: IgnorePointer(
              ignoring: isEditMode,
              child: RepaintBoundary(
                child: FlightWidgetContent(
                  model: model,
                  telemetry: telemetry,
                  tier: tier,
                  mapControlTarget: state.controlTarget(model.id),
                  showBuiltInMapControls:
                      model.type == WidgetType.map &&
                      state.builtInControlsVisible(model),
                ),
              ),
            ),
          ),
        ),
        if (isEditMode)
          Positioned.fill(
            child: EditHitArea(
              model: model,
              editMode: editMode,
              cellWidth: cellWidth,
              cellHeight: cellHeight,
              isSelected: isSelected,
            ),
          ),
      ],
    );
  }
}
