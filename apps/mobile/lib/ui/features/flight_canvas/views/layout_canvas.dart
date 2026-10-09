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
import '../../layout_editor/view_models/edit_mode_view_model.dart';
import '../../../../services/airspace_service.dart';
import '../../../../widgets/flight/airspace_warning_banner_hud.dart';
import '../../layout_editor/views/edit_frame.dart';
import '../../layout_editor/views/edit_toolbar.dart';
import '../../layout_editor/views/inspector_panel.dart';
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

  /// Edit dock (inspector + toolbar) placed away from the selected widget:
  /// a side panel on wide canvases, otherwise a bottom toolbar with the
  /// inspector above it, or at the top when the selection is in the lower
  /// half of the canvas.
  List<Widget> _buildEditDock({
    required Size outerSize,
    required Offset canvasOffset,
    required double cellWidth,
    required double cellHeight,
    required CanvasLayoutState state,
    required WidgetPlacementModel? selected,
  }) {
    final inspector = selected == null
        ? null
        : WidgetInspectorPanel(
            model: selected,
            screenManager: widget.screenManager,
          );
    final toolbar = EditToolbar(
      screenManager: widget.screenManager,
      widgets: state.widgets,
      selectedWidget: selected,
    );
    final selectedCenter = selected == null
        ? null
        : canvasOffset +
              Offset(
                (selected.x + selected.w / 2) * cellWidth,
                (selected.y + selected.h / 2) * cellHeight,
              );

    final sideDock =
        outerSize.width > outerSize.height &&
        outerSize.width >= kSideDockMinWidth;
    if (sideDock) {
      final panelWidth = math.min(
        kEditChromeMaxWidth,
        math.max(320.0, outerSize.width * 0.42),
      );
      final dockLeft =
          selectedCenter != null && selectedCenter.dx > outerSize.width / 2;
      return [
        Positioned(
          key: const Key('edit_dock_side'),
          top: 8,
          bottom: 8,
          left: dockLeft ? 8 : null,
          right: dockLeft ? null : 8,
          width: panelWidth,
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (inspector != null) ...[
                  Flexible(child: SingleChildScrollView(child: inspector)),
                  const SizedBox(height: 6),
                ],
                toolbar,
              ],
            ),
          ),
        ),
      ];
    }

    final inspectorOnTop =
        selectedCenter != null && selectedCenter.dy > outerSize.height / 2;
    Widget constrain(Widget child) => Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: outerSize.width > kWideCanvasBreakpoint
              ? kEditChromeMaxWidth
              : double.infinity,
        ),
        child: child,
      ),
    );

    return [
      if (inspector != null && inspectorOnTop)
        Positioned(
          key: const Key('edit_dock_top'),
          left: 8,
          right: 8,
          top: 8,
          child: SafeArea(bottom: false, child: constrain(inspector)),
        ),
      Positioned(
        key: const Key('edit_dock_bottom'),
        left: 8,
        right: 8,
        bottom: 8,
        child: SafeArea(
          top: false,
          child: constrain(
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (inspector != null && !inspectorOnTop) ...[
                  inspector,
                  const SizedBox(height: 6),
                ],
                toolbar,
              ],
            ),
          ),
        ),
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
