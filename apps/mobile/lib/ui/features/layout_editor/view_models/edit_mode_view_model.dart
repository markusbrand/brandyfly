import 'package:flutter/foundation.dart';

import '../../../../data/repositories/layout_repository.dart';
import '../../../../domain/models/ui_config.dart';
import '../../../../domain/models/widget_catalog.dart';
import '../../../../domain/use_cases/alignment_detector.dart';
import '../../../../domain/use_cases/layout_editor.dart';

/// Edit mode state (selection, edited variant, interaction guides) and layout
/// editing commands for the active screen.
///
/// All layout rules are delegated to [LayoutEditor]; persistence goes through
/// [LayoutRepository]. Listeners are notified exactly once per effective
/// change (including layout changes made through the repository) and not at
/// all for no-op commands.
class EditModeViewModel extends ChangeNotifier {
  EditModeViewModel(
    this._repository, {
    this._editor = const LayoutEditor(),
    this._detector = const AlignmentDetector(),
    String Function()? idGenerator,
  }) : _newId = idGenerator ?? _timestampId {
    _repository.addListener(_onRepositoryChanged);
  }

  static int _idCounter = 0;
  static String _timestampId() =>
      'w_${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';

  final LayoutRepository _repository;
  final LayoutEditor _editor;
  final AlignmentDetector _detector;
  final String Function() _newId;

  bool _isEditMode = false;
  String? _selectedWidgetId;
  LayoutVariant _editedVariant = LayoutVariant.tall;
  CanvasShape _canvasShape = CanvasShape.tall;
  CellGeometry _geometry = CellGeometry.unknown;
  String? _interactingId;
  final ValueNotifier<AlignmentResult> _guides = ValueNotifier<AlignmentResult>(
    AlignmentResult.none,
  );

  int _batchDepth = 0;
  bool _pendingNotify = false;

  LayoutRepository get repository => _repository;
  LayoutEditor get editor => _editor;

  bool get isEditMode => _isEditMode;
  String? get selectedWidgetId => _selectedWidgetId;
  CanvasShape get canvasShape => _canvasShape;
  CellGeometry get geometry => _geometry;

  /// Alignment guides and overlaps for the selected widget. Updated during
  /// move/resize interactions without rebuilding the whole canvas.
  ValueListenable<AlignmentResult> get guides => _guides;

  FlightScreenModel get activeScreen => _repository.config.activeScreen;

  /// Variant being edited. Falls back to tall when the active screen has no
  /// wide variant.
  LayoutVariant get editedVariant =>
      _editedVariant == LayoutVariant.wide && !activeScreen.hasWideVariant
      ? LayoutVariant.tall
      : _editedVariant;

  List<WidgetPlacementModel> get editedWidgets =>
      activeScreen.widgetsFor(editedVariant);

  WidgetPlacementModel? get selectedWidget {
    final id = _selectedWidgetId;
    if (id == null) return null;
    for (final w in editedWidgets) {
      if (w.id == id) return w;
    }
    return null;
  }

  /// Variant rendered for [shape] outside edit mode.
  LayoutVariant variantForShape(CanvasShape shape) =>
      shape == CanvasShape.wide && activeScreen.hasWideVariant
      ? LayoutVariant.wide
      : LayoutVariant.tall;

  // ---------------------------------------------------------------------------
  // Notification batching

  /// Runs [action] and emits at most one notification for all changes in it.
  void batch(void Function() action) {
    _batchDepth++;
    try {
      action();
    } finally {
      _batchDepth--;
      if (_batchDepth == 0 && _pendingNotify) {
        _pendingNotify = false;
        notifyListeners();
      }
    }
  }

  void _notify() {
    if (_batchDepth > 0) {
      _pendingNotify = true;
    } else {
      notifyListeners();
    }
  }

  void _onRepositoryChanged() => _notify();

  // ---------------------------------------------------------------------------
  // Canvas reporting (silent: called during layout)

  /// Records the current canvas shape and cell geometry used for the 48 dp
  /// touch-target rule. Does not notify.
  void reportCanvas(CanvasShape shape, CellGeometry geometry) {
    _canvasShape = shape;
    _geometry = geometry;
  }

  // ---------------------------------------------------------------------------
  // Edit mode and selection

  void setEditMode(bool enabled) {
    if (_isEditMode == enabled) return;
    batch(() {
      _isEditMode = enabled;
      if (enabled) {
        _editedVariant = variantForShape(_canvasShape);
      } else {
        _selectedWidgetId = null;
        _clearInteraction();
      }
      _notify();
    });
  }

  void select(String? id) {
    if (_selectedWidgetId == id) return;
    _selectedWidgetId = id;
    _interactingId = null;
    _refreshGuides();
    _notify();
  }

  /// Clears selection without notifying (used inside batches).
  void clearSelectionSilently() {
    _selectedWidgetId = null;
    _clearInteraction();
  }

  /// Switches the edited variant. Returns false when [variant] is wide and the
  /// active screen has no wide variant yet (see [createWideFromTall]).
  bool setEditedVariant(LayoutVariant variant) {
    if (variant == LayoutVariant.wide && !activeScreen.hasWideVariant) {
      return false;
    }
    if (_editedVariant == variant) return true;
    _editedVariant = variant;
    _notify();
    return true;
  }

  void createWideFromTall() {
    final screen = activeScreen;
    batch(() {
      if (!screen.hasWideVariant) {
        _repository.updateScreen(
          screen.id,
          (s) => s.copyWith(wideWidgets: _editor.copyForVariant(s.widgets)),
        );
      }
      if (_editedVariant != LayoutVariant.wide) {
        _editedVariant = LayoutVariant.wide;
        _notify();
      }
    });
  }

  void deleteWideVariant() {
    final screen = activeScreen;
    if (!screen.hasWideVariant) return;
    batch(() {
      _repository.updateScreen(
        screen.id,
        (s) => s.copyWith(clearWideWidgets: true),
      );
      _editedVariant = LayoutVariant.tall;
    });
  }

  // ---------------------------------------------------------------------------
  // Layout commands (operate on the edited variant of the active screen)

  void _apply(
    List<WidgetPlacementModel> Function(List<WidgetPlacementModel> list) op,
  ) {
    final screen = activeScreen;
    final variant = editedVariant;
    final before = screen.widgetsFor(variant);
    final after = op(before);
    if (identical(after, before)) return;
    batch(() {
      _repository.updateScreen(
        screen.id,
        (s) => s.withVariantWidgets(variant, after),
      );
      _refreshGuides();
    });
  }

  CellGeometry? get _touchGeometry => _geometry.isKnown ? _geometry : null;

  void move(String id, int dx, int dy) =>
      _apply((l) => _editor.move(l, id, dx, dy, geometry: _touchGeometry));

  void resize(String id, int dw, int dh) =>
      _apply((l) => _editor.resize(l, id, dw, dh, geometry: _touchGeometry));

  void applyPreset(String id, SizePreset preset) => _apply(
    (l) => _editor.applyPreset(l, id, preset, geometry: _touchGeometry),
  );

  void updatePlacement(WidgetPlacementModel placement) =>
      _apply((l) => _editor.update(l, placement, geometry: _touchGeometry));

  void fixTouchSize(String id) {
    if (!_geometry.isKnown) return;
    _apply((l) => _editor.fixTouchSize(l, id, _geometry));
  }

  bool isBelowTouchTarget(WidgetPlacementModel placement) =>
      _geometry.isKnown && _editor.isBelowTouchTarget(placement, _geometry);

  /// Adds a widget of [type] to the edited variant and returns its id.
  String addWidget(WidgetType type) {
    final id = _newId();
    _apply((l) => _editor.add(l, type, id, geometry: _touchGeometry));
    return id;
  }

  void removeWidget(String id) {
    batch(() {
      if (_selectedWidgetId == id) {
        _selectedWidgetId = null;
        _clearInteraction();
        _notify();
      }
      _apply((l) => _editor.remove(l, id));
    });
  }

  void bringToFront(String id) => _apply((l) => _editor.bringToFront(l, id));
  void bringForward(String id) => _apply((l) => _editor.bringForward(l, id));
  void sendBackward(String id) => _apply((l) => _editor.sendBackward(l, id));
  void sendToBack(String id) => _apply((l) => _editor.sendToBack(l, id));

  // ---------------------------------------------------------------------------
  // Interaction guides

  /// Starts a move/resize interaction; alignment guides are shown until
  /// [endInteraction].
  void beginInteraction(String id) {
    _interactingId = id;
    _refreshGuides();
  }

  void endInteraction() {
    _interactingId = null;
    _refreshGuides();
  }

  void _clearInteraction() {
    _interactingId = null;
    _guides.value = AlignmentResult.none;
  }

  void _refreshGuides() {
    final selected = _selectedWidgetId;
    if (!_isEditMode || selected == null) {
      if (!_guides.value.isEmpty) _guides.value = AlignmentResult.none;
      return;
    }
    _guides.value = _detector.detect(
      editedWidgets,
      selected,
      includeGuides: _interactingId == selected,
    );
  }

  /// Recomputes overlap highlights for the current selection (e.g. after the
  /// canvas rebuilt with a new layout).
  void refreshGuides() => _refreshGuides();

  @override
  void dispose() {
    _repository.removeListener(_onRepositoryChanged);
    _guides.dispose();
    super.dispose();
  }
}
