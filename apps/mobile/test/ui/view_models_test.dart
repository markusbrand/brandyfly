import 'package:brandyfly/data/repositories/layout_repository.dart';
import 'package:brandyfly/domain/models/ui_config.dart';
import 'package:brandyfly/domain/models/widget_catalog.dart';
import 'package:brandyfly/ui/features/flight_canvas/view_models/flight_canvas_view_model.dart';
import 'package:brandyfly/ui/features/layout_editor/view_models/edit_mode_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

WidgetPlacementModel _p(
  String id,
  WidgetType type,
  int x,
  int y,
  int w,
  int h, {
  String? target,
  MapBuiltInControls? builtIn,
}) => WidgetPlacementModel(
  id: id,
  type: type,
  x: x,
  y: y,
  w: w,
  h: h,
  mapControlTarget: target,
  mapBuiltInControls: builtIn,
);

UIConfig _config({List<WidgetPlacementModel>? wide}) => UIConfig(
  activeScreenId: 's',
  screens: [
    FlightScreenModel(
      id: 's',
      name: 'S',
      widgets: [
        _p('map', WidgetType.map, 0, 0, 16, 32),
        _p('alt', WidgetType.altitude, 0, 0, 4, 4),
        _p('btn', WidgetType.mapRecenter, 12, 28, 3, 3),
      ],
      wideWidgets: wide,
    ),
    const FlightScreenModel(id: 'other', name: 'Other', widgets: []),
  ],
);

void main() {
  group('EditModeViewModel', () {
    late LayoutRepository repo;
    late EditModeViewModel vm;
    late int notifications;
    var idCounter = 0;

    setUp(() {
      repo = LayoutRepository(initialConfig: _config());
      vm = EditModeViewModel(repo, idGenerator: () => 'new_${idCounter++}');
      notifications = 0;
      vm.addListener(() => notifications++);
    });

    tearDown(() {
      vm.dispose();
      repo.dispose();
    });

    test('edit mode and selection notify once per change, never on no-op', () {
      vm.setEditMode(true);
      expect(notifications, 1);
      vm.setEditMode(true);
      expect(notifications, 1);

      vm.select('alt');
      expect(notifications, 2);
      expect(vm.selectedWidget?.id, 'alt');
      vm.select('alt');
      expect(notifications, 2);

      vm.setEditMode(false);
      expect(notifications, 3);
      expect(vm.selectedWidgetId, isNull);
    });

    test('layout commands notify exactly once per effective change', () {
      vm.setEditMode(true);
      notifications = 0;

      vm.move('alt', 1, 0);
      expect(notifications, 1);
      expect(vm.editedWidgets[1].x, 1);

      vm.move('alt', -5, 0); // clamps to x=0: effective
      expect(notifications, 2);
      vm.move('alt', -1, 0); // already at 0: no-op
      expect(notifications, 2);

      vm.resize('alt', 2, 1);
      expect(notifications, 3);
      expect(vm.editedWidgets[1].w, 6);

      vm.applyPreset('alt', SizePreset.s);
      expect(notifications, 4);
      expect(vm.editedWidgets[1].w, 3);

      vm.bringToFront('alt');
      expect(notifications, 5);
      expect(vm.editedWidgets.last.id, 'alt');
      vm.bringToFront('alt');
      expect(notifications, 5);

      vm.sendToBack('alt');
      vm.bringForward('alt');
      vm.sendBackward('alt');
      expect(notifications, 8);

      vm.updatePlacement(vm.editedWidgets.firstWhere((w) => w.id == 'alt'));
      expect(notifications, 8, reason: 'unchanged placement is a no-op');
    });

    test('remove clears selection with a single notification', () {
      vm.setEditMode(true);
      vm.select('alt');
      notifications = 0;
      vm.removeWidget('alt');
      expect(notifications, 1);
      expect(vm.selectedWidgetId, isNull);
      expect(vm.editedWidgets.any((w) => w.id == 'alt'), isFalse);
      vm.removeWidget('alt');
      expect(notifications, 1);
    });

    test('addWidget uses catalog defaults and 48 dp rule', () {
      vm.setEditMode(true);
      vm.reportCanvas(
        CanvasShape.tall,
        const CellGeometry(390 / 16, 844 / 32),
      );
      final id = vm.addWidget(WidgetType.mapZoomIn);
      final added = vm.editedWidgets.firstWhere((w) => w.id == id);
      expect(added.w, 3);
      expect(added.h, 3);
      vm.resize(id, -5, -5);
      final shrunk = vm.editedWidgets.firstWhere((w) => w.id == id);
      expect(shrunk.w, 2);
      expect(shrunk.h, 2);
      expect(vm.isBelowTouchTarget(shrunk), isFalse);
    });

    test('fixTouchSize grows a too-small control after canvas shrinks', () {
      vm.setEditMode(true);
      vm.updatePlacement(
        _p('btn', WidgetType.mapRecenter, 12, 28, 1, 1, target: 'auto'),
      );
      vm.reportCanvas(CanvasShape.tall, const CellGeometry(20, 20));
      final btn = vm.editedWidgets.firstWhere((w) => w.id == 'btn');
      expect(vm.isBelowTouchTarget(btn), isTrue);
      vm.fixTouchSize('btn');
      final fixed = vm.editedWidgets.firstWhere((w) => w.id == 'btn');
      expect(fixed.w, 3);
      expect(fixed.h, 3);
      expect(vm.isBelowTouchTarget(fixed), isFalse);
    });

    test('wide variant create, edit independently and delete', () {
      vm.setEditMode(true);
      expect(vm.setEditedVariant(LayoutVariant.wide), isFalse);
      expect(vm.editedVariant, LayoutVariant.tall);

      notifications = 0;
      vm.createWideFromTall();
      expect(notifications, 1);
      expect(vm.editedVariant, LayoutVariant.wide);
      expect(vm.activeScreen.wideWidgets!.map((w) => w.id), [
        'map',
        'alt',
        'btn',
      ]);

      vm.move('alt', 4, 0);
      expect(vm.activeScreen.wideWidgets![1].x, 4);
      expect(vm.activeScreen.widgets[1].x, 0, reason: 'tall untouched');

      vm.setEditedVariant(LayoutVariant.tall);
      vm.removeWidget('btn');
      expect(vm.activeScreen.widgets.length, 2);
      expect(vm.activeScreen.wideWidgets!.length, 3, reason: 'wide untouched');

      vm.deleteWideVariant();
      expect(vm.activeScreen.hasWideVariant, isFalse);
      expect(vm.editedVariant, LayoutVariant.tall);
    });

    test('entering edit mode on a wide canvas edits the wide variant', () {
      repo.replace(
        _config(wide: [_p('alt', WidgetType.altitude, 8, 0, 4, 4)]),
      );
      vm.reportCanvas(CanvasShape.wide, const CellGeometry(50, 12));
      vm.setEditMode(true);
      expect(vm.editedVariant, LayoutVariant.wide);
      vm.select('alt');
      expect(vm.selectedWidget!.x, 8);
    });

    test('guides appear during interaction and clear on release', () {
      vm.setEditMode(true);
      repo.replace(
        UIConfig(
          activeScreenId: 's',
          screens: [
            FlightScreenModel(
              id: 's',
              name: 'S',
              widgets: [
                _p('a', WidgetType.altitude, 2, 0, 4, 4),
                _p('b', WidgetType.speed, 2, 10, 4, 4),
              ],
            ),
          ],
        ),
      );
      vm.select('b');
      expect(vm.guides.value.guides, isEmpty);
      vm.beginInteraction('b');
      expect(vm.guides.value.guides, isNotEmpty);
      vm.move('b', 0, -8); // overlaps 'a' now
      expect(vm.guides.value.overlaps, isNotEmpty);
      vm.endInteraction();
      expect(vm.guides.value.guides, isEmpty);
      expect(vm.guides.value.overlaps, isNotEmpty);
    });

    test('external repository change notifies once', () {
      repo.replace(repo.config.copyWith(activeScreenId: 'other'));
      expect(notifications, 1);
    });
  });

  group('FlightCanvasViewModel', () {
    final canvas = FlightCanvasViewModel();
    final tallOnly = _config().screens.first;
    final withWide = tallOnly.copyWith(
      wideWidgets: [_p('alt', WidgetType.altitude, 8, 0, 4, 4)],
    );

    test('tall canvas renders tall layout', () {
      final s = canvas.resolve(screen: withWide, shape: CanvasShape.tall);
      expect(s.variant, LayoutVariant.tall);
      expect(s.letterboxed, isFalse);
    });

    test('wide canvas renders wide variant when present', () {
      final s = canvas.resolve(screen: withWide, shape: CanvasShape.wide);
      expect(s.variant, LayoutVariant.wide);
      expect(s.widgets.single.x, 8);
    });

    test('wide canvas without wide variant stretches tall layout', () {
      final s = canvas.resolve(screen: tallOnly, shape: CanvasShape.wide);
      expect(s.variant, LayoutVariant.tall);
      expect(s.letterboxed, isFalse);
    });

    test('editing non-matching variant is letterboxed', () {
      final s = canvas.resolve(
        screen: withWide,
        shape: CanvasShape.tall,
        isEditMode: true,
        editedVariant: LayoutVariant.wide,
      );
      expect(s.variant, LayoutVariant.wide);
      expect(s.letterboxed, isTrue);
      final s2 = canvas.resolve(
        screen: tallOnly,
        shape: CanvasShape.wide,
        isEditMode: true,
        editedVariant: LayoutVariant.tall,
      );
      expect(s2.letterboxed, isFalse, reason: 'stretched tall is the flight view');
    });

    test('resolve is memoized for identical inputs', () {
      final a = canvas.resolve(screen: tallOnly, shape: CanvasShape.tall);
      final b = canvas.resolve(screen: tallOnly, shape: CanvasShape.tall);
      expect(identical(a, b), isTrue);
    });

    test('built-in map control visibility: auto / always / never', () {
      final s = canvas.resolve(screen: tallOnly, shape: CanvasShape.tall);
      final map = s.widgets.first;
      expect(s.controlTarget('btn'), 'map');
      expect(s.builtInControlsVisible(map), isFalse);

      final noControls = tallOnly.copyWith(
        widgets: tallOnly.widgets.where((w) => w.id != 'btn').toList(),
      );
      final s2 = FlightCanvasViewModel().resolve(
        screen: noControls,
        shape: CanvasShape.tall,
      );
      expect(s2.builtInControlsVisible(s2.widgets.first), isTrue);

      expect(
        s.builtInControlsVisible(
          map.copyWith(mapBuiltInControls: MapBuiltInControls.always),
        ),
        isTrue,
      );
      expect(
        s2.builtInControlsVisible(
          s2.widgets.first.copyWith(
            mapBuiltInControls: MapBuiltInControls.never,
          ),
        ),
        isFalse,
      );
    });
  });
}
