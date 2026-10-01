import '../../../../domain/models/ui_config.dart';
import '../../../../domain/use_cases/map_control_resolver.dart';

/// Resolved, render-ready layout of the active screen for one canvas.
class CanvasLayoutState {
  const CanvasLayoutState({
    required this.screen,
    required this.variant,
    required this.widgets,
    required this.letterboxed,
    required this.mapsWithExternalControls,
    required this._controlTargets,
  });

  final FlightScreenModel screen;

  /// Variant whose widgets are rendered.
  final LayoutVariant variant;
  final List<WidgetPlacementModel> widgets;

  /// True when the rendered variant does not match the canvas shape (edit
  /// preview) and must be shown in a letterboxed box.
  final bool letterboxed;
  final Set<String> mapsWithExternalControls;
  final Map<String, String?> _controlTargets;

  static const MapControlResolver _resolver = MapControlResolver();

  /// Resolved map id for a map control widget (null = no map).
  String? controlTarget(String controlId) => _controlTargets[controlId];

  bool builtInControlsVisible(WidgetPlacementModel map) =>
      _resolver.builtInControlsVisible(map, mapsWithExternalControls);
}

/// Derives the rendered layout (variant choice, letterboxing, map control
/// targeting and built-in map control visibility) from the active screen and
/// canvas shape. Results are memoized per input so rebuilds are cheap.
class FlightCanvasViewModel {
  FlightCanvasViewModel({this._resolver = const MapControlResolver()});

  final MapControlResolver _resolver;

  FlightScreenModel? _lastScreen;
  CanvasShape? _lastShape;
  bool? _lastEdit;
  LayoutVariant? _lastEdited;
  CanvasLayoutState? _last;

  /// Variant rendered for [shape] in flight.
  static LayoutVariant flightVariant(
    FlightScreenModel screen,
    CanvasShape shape,
  ) => shape == CanvasShape.wide && screen.hasWideVariant
      ? LayoutVariant.wide
      : LayoutVariant.tall;

  CanvasLayoutState resolve({
    required FlightScreenModel screen,
    required CanvasShape shape,
    bool isEditMode = false,
    LayoutVariant editedVariant = LayoutVariant.tall,
  }) {
    final cached = _last;
    if (cached != null &&
        identical(_lastScreen, screen) &&
        _lastShape == shape &&
        _lastEdit == isEditMode &&
        _lastEdited == editedVariant) {
      return cached;
    }

    final LayoutVariant variant;
    final bool letterboxed;
    if (isEditMode) {
      variant = editedVariant == LayoutVariant.wide && screen.hasWideVariant
          ? LayoutVariant.wide
          : LayoutVariant.tall;
      letterboxed = variant != flightVariant(screen, shape);
    } else {
      variant = flightVariant(screen, shape);
      letterboxed = false;
    }

    final widgets = screen.widgetsFor(variant);
    final targets = <String, String?>{
      for (final w in widgets)
        if (w.type.isMapControl) w.id: _resolver.resolveTarget(widgets, w),
    };

    final state = CanvasLayoutState(
      screen: screen,
      variant: variant,
      widgets: widgets,
      letterboxed: letterboxed,
      mapsWithExternalControls: _resolver.mapsWithExternalControls(widgets),
      controlTargets: targets,
    );
    _lastScreen = screen;
    _lastShape = shape;
    _lastEdit = isEditMode;
    _lastEdited = editedVariant;
    _last = state;
    return state;
  }
}
