import 'package:brandyfly/domain/models/cockpit_telemetry.dart';
import 'package:brandyfly/domain/models/ui_config.dart';
import 'package:brandyfly/domain/models/widget_catalog.dart';
import 'package:brandyfly/domain/use_cases/alignment_detector.dart';
import 'package:brandyfly/services/screen_manager_service.dart';
import 'package:brandyfly/ui/core/theme/cockpit_tokens.dart';
import 'package:brandyfly/ui/features/flight_canvas/views/grid_guide_painter.dart';
import 'package:brandyfly/ui/features/flight_canvas/views/layout_canvas.dart';
import 'package:brandyfly/ui/features/instruments/views/numeric_text_widget.dart';
import 'package:brandyfly/ui/features/map/views/map_widget.dart';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

WidgetPlacementModel _p(
  String id,
  WidgetType type,
  int x,
  int y,
  int w,
  int h,
) => WidgetPlacementModel(id: id, type: type, x: x, y: y, w: w, h: h);

ScreenManagerService _manager(
  List<WidgetPlacementModel> widgets, {
  List<WidgetPlacementModel>? wide,
  LayoutStrategyStyle strategy = LayoutStrategyStyle.freeformHud,
}) => ScreenManagerService(
  initialConfig: UIConfig(
    activeScreenId: 's',
    screens: [
      FlightScreenModel(
        id: 's',
        name: 'S',
        layoutStrategy: strategy,
        widgets: widgets,
        wideWidgets: wide,
      ),
    ],
  ),
);

Future<void> _setView(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _app(ScreenManagerService manager, {ValueNotifier<CockpitTelemetry>? telemetry}) =>
    MaterialApp(
      home: Scaffold(
        body: LayoutStrategyContainer(
          screenManager: manager,
          telemetry: telemetry ?? ValueNotifier(const CockpitTelemetry()),
        ),
      ),
    );

Rect _rectOf(WidgetTester tester, String id) =>
    tester.getRect(find.byKey(Key('positioned_$id')));

void main() {
  final standard = [
    _p('map', WidgetType.map, 0, 0, 16, 32),
    _p('alt', WidgetType.altitude, 0, 0, 4, 8),
    _p('spd', WidgetType.speed, 0, 8, 4, 8),
    _p('vario', WidgetType.varioBar, 0, 16, 4, 16),
  ];

  group('Responsive flight canvas', () {
    for (final strategy in LayoutStrategyStyle.values) {
      testWidgets('${strategy.name} renders without scrolling in flight and edit', (
        tester,
      ) async {
        await _setView(tester, const Size(390, 844));
        final manager = _manager(standard, strategy: strategy);
        await tester.pumpWidget(_app(manager));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.descendant(
            of: find.byType(LayoutStrategyContainer),
            matching: find.byType(Scrollable),
          ),
          findsNothing,
        );

        manager.toggleEditMode(true);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        // The canvas itself never scrolls (edit chrome is docked outside it).
        expect(
          find.descendant(
            of: find.byKey(const Key('flight_canvas')),
            matching: find.byType(Scrollable),
          ),
          findsNothing,
        );
      });
    }

    testWidgets('cells are canvas/16 by canvas/32 and full widgets fill edge-to-edge', (
      tester,
    ) async {
      await _setView(tester, const Size(400, 800));
      await tester.pumpWidget(_app(_manager(standard)));
      await tester.pumpAndSettle();
      expect(_rectOf(tester, 'map'), const Rect.fromLTWH(0, 0, 400, 800));
      expect(_rectOf(tester, 'spd'), const Rect.fromLTWH(0, 200, 100, 200));
    });

    testWidgets('wide canvas renders wide variant; tall layout otherwise', (
      tester,
    ) async {
      final manager = _manager(
        standard,
        wide: [
          _p('map', WidgetType.map, 0, 0, 16, 32),
          _p('alt', WidgetType.altitude, 12, 0, 4, 8),
        ],
      );
      await _setView(tester, const Size(400, 800));
      await tester.pumpWidget(_app(manager));
      await tester.pumpAndSettle();
      expect(_rectOf(tester, 'alt').left, 0);
      expect(find.byKey(const Key('positioned_spd')), findsOneWidget);
      final mapState = tester.state(find.byType(MapWidget));

      // Rotate / resize the window across the width = height boundary.
      tester.view.physicalSize = const Size(800, 400);
      await tester.pumpAndSettle();
      expect(_rectOf(tester, 'alt').left, 600);
      expect(find.byKey(const Key('positioned_spd')), findsNothing);
      expect(
        tester.state(find.byType(MapWidget)),
        same(mapState),
        reason: 'map camera state survives the variant switch',
      );
    });

    testWidgets('wide canvas without wide variant stretches tall layout', (
      tester,
    ) async {
      await _setView(tester, const Size(800, 400));
      await tester.pumpWidget(_app(_manager(standard)));
      await tester.pumpAndSettle();
      expect(_rectOf(tester, 'map'), const Rect.fromLTWH(0, 0, 800, 400));
      expect(_rectOf(tester, 'vario'), const Rect.fromLTWH(0, 200, 200, 200));
      expect(tester.takeException(), isNull);
    });

    testWidgets('editing the wide variant on a tall canvas is letterboxed 16:9', (
      tester,
    ) async {
      await _setView(tester, const Size(400, 800));
      final manager = _manager(standard, wide: standard);
      manager.toggleEditMode(true);
      manager.editMode.setEditedVariant(LayoutVariant.wide);
      await tester.pumpWidget(_app(manager));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('letterbox_preview')), findsOneWidget);
      final map = _rectOf(tester, 'map');
      expect(map.width, 400);
      expect(map.height, closeTo(225, 0.01));

      manager.toggleEditMode(false);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('letterbox_preview')), findsNothing);
      expect(_rectOf(tester, 'map').height, 800);
    });

    testWidgets('unbounded and zero constraints do not throw', (tester) async {
      final manager = _manager(standard);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LayoutStrategyContainer(
                screenManager: manager,
                telemetryData: const {'altitude': 1000.0},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(LayoutStrategyContainer)).height,
        kUnboundedCanvasFallbackHeight,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox.shrink(
            child: LayoutStrategyContainer(
              screenManager: manager,
              telemetryData: const {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('instrument tier follows rendered size on each canvas', (
      tester,
    ) async {
      final manager = _manager([_p('alt', WidgetType.altitude, 0, 0, 2, 2)]);
      await _setView(tester, const Size(400, 800)); // 50x50 -> compact
      await tester.pumpWidget(_app(manager));
      await tester.pumpAndSettle();
      expect(find.text('ALTITUDE'), findsNothing);
      expect(find.text('m'), findsOneWidget);

      tester.view.physicalSize = const Size(1600, 1600); // 200x100 -> regular
      await tester.pumpAndSettle();
      expect(find.text('ALTITUDE'), findsOneWidget);

      tester.view.physicalSize = const Size(320, 480); // 40x30 -> tiny
      await tester.pumpAndSettle();
      expect(find.text('ALTITUDE'), findsNothing);
      expect(find.text('m'), findsNothing);
      expect(find.text('1450'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Grid and guide painters', () {
    testWidgets('grid and guide layers exist only in edit mode', (tester) async {
      await _setView(tester, const Size(400, 800));
      final manager = _manager(standard);
      await tester.pumpWidget(_app(manager));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('edit_grid_layer')), findsNothing);
      expect(find.byKey(const Key('edit_guide_layer')), findsNothing);

      manager.toggleEditMode(true);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('edit_grid_layer')), findsOneWidget);
      expect(find.byKey(const Key('edit_guide_layer')), findsOneWidget);
    });

    test('grid painter repaints only on geometry change', () {
      final a = GridPainter(cellWidth: 25, cellHeight: 25);
      expect(a.shouldRepaint(GridPainter(cellWidth: 25, cellHeight: 25)), isFalse);
      expect(a.shouldRepaint(GridPainter(cellWidth: 30, cellHeight: 25)), isTrue);
      const r = AlignmentResult();
      final g = GuidePainter(cellWidth: 25, cellHeight: 25, result: r);
      expect(g.shouldRepaint(GuidePainter(cellWidth: 25, cellHeight: 25, result: r)), isFalse);
      expect(
        g.shouldRepaint(
          GuidePainter(
            cellWidth: 25,
            cellHeight: 25,
            result: AlignmentResult(overlaps: [const GridRect(0, 0, 1, 1)]),
          ),
        ),
        isTrue,
      );
    });

    test('painters guard against zero-size canvases', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      GridPainter(cellWidth: 0, cellHeight: 0).paint(canvas, Size.zero);
      GuidePainter(
        cellWidth: 10,
        cellHeight: 10,
        result: const AlignmentResult(
          guides: [AlignmentGuide(GuideAxis.vertical, 2)],
        ),
      ).paint(canvas, Size.zero);
      recorder.endRecording();
    });
  });

  group('Edit chrome', () {
    testWidgets('alignment guides show during drag and clear on release', (
      tester,
    ) async {
      await _setView(tester, const Size(400, 800));
      final manager = _manager([
        _p('a', WidgetType.altitude, 2, 0, 4, 4),
        _p('b', WidgetType.speed, 8, 12, 4, 4),
      ]);
      manager.toggleEditMode(true);
      await tester.pumpWidget(_app(manager));
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('widget_box_b'))),
      );
      await gesture.moveBy(const Offset(-30, 0));
      await gesture.moveBy(const Offset(-30, 0));
      await gesture.moveBy(const Offset(-90, 0));
      await tester.pump();
      final b = manager.activeScreen.widgets.last;
      expect(b.x, 2, reason: 'dragged 150 px = 6 cells left');
      expect(manager.editMode.guides.value.guides, isNotEmpty);
      await gesture.up();
      await tester.pump();
      expect(manager.editMode.guides.value.guides, isEmpty);
    });

    testWidgets('overlap with another widget is highlighted', (tester) async {
      await _setView(tester, const Size(400, 800));
      final manager = _manager([
        _p('a', WidgetType.altitude, 0, 0, 4, 4),
        _p('b', WidgetType.speed, 2, 2, 4, 4),
      ]);
      manager.toggleEditMode(true);
      manager.selectWidget('b');
      await tester.pumpWidget(_app(manager));
      await tester.pumpAndSettle();
      expect(manager.editMode.guides.value.overlaps, isNotEmpty);
    });

    testWidgets('corner handle resizes in whole cells', (tester) async {
      await _setView(tester, const Size(400, 800));
      final manager = _manager([_p('a', WidgetType.altitude, 2, 2, 4, 4)]);
      manager.toggleEditMode(true);
      manager.selectWidget('a');
      await tester.pumpWidget(_app(manager));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const Key('resize_handle_a')),
        const Offset(50, 75),
      );
      await tester.pumpAndSettle();
      final a = manager.activeScreen.widgets.single;
      expect(a.w, 6);
      expect(a.h, 7);
    });

    testWidgets('1x1 widget selection chrome renders outside without overflow', (
      tester,
    ) async {
      await _setView(tester, const Size(390, 844));
      final manager = _manager([_p('tiny', WidgetType.altitude, 7, 15, 1, 1)]);
      manager.toggleEditMode(true);
      manager.selectWidget('tiny');
      await tester.pumpWidget(_app(manager));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final widgetRect = _rectOf(tester, 'tiny');
      final handle = tester.getRect(find.byKey(const Key('resize_handle_tiny')));
      expect(handle.width, greaterThanOrEqualTo(40));
      expect(handle.right, greaterThan(widgetRect.right));
      expect(find.byKey(const Key('size_tag_tiny')), findsOneWidget);
      expect(find.textContaining('tiny'), findsWidgets);
    });

    testWidgets('inspector presets resize the selected widget', (tester) async {
      await _setView(tester, const Size(400, 800));
      final manager = _manager([_p('a', WidgetType.altitude, 14, 30, 2, 2)]);
      manager.toggleEditMode(true);
      manager.selectWidget('a');
      await tester.pumpWidget(_app(manager));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('btn_inspector_preset_l')));
      await tester.pumpAndSettle();
      final a = manager.activeScreen.widgets.single;
      expect([a.x, a.y, a.w, a.h], [8, 27, 8, 5]);
      expect(find.byKey(const Key('inspector_tier_badge')), findsOneWidget);
    });

    testWidgets('too-small map control is flagged and fixed from inspector', (
      tester,
    ) async {
      await _setView(tester, const Size(390, 844));
      final manager = _manager([
        _p('m', WidgetType.map, 0, 0, 16, 32),
        _p('c', WidgetType.mapRecenter, 4, 4, 1, 1),
      ]);
      manager.toggleEditMode(true);
      manager.selectWidget('c');
      await tester.pumpWidget(_app(manager));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('touch_warning_c')), findsOneWidget);
      await tester.tap(find.byKey(const Key('btn_inspector_fix_size')));
      await tester.pumpAndSettle();
      final c = manager.activeScreen.widgets.last;
      expect([c.w, c.h], [2, 2]);
      expect(find.byKey(const Key('touch_warning_c')), findsNothing);
      expect(find.byKey(const Key('btn_inspector_fix_size')), findsNothing);
    });

    const sectionKeys = {
      'size': ['btn_inspector_preset_s', 'btn_inspector_preset_full'],
      'resize': ['btn_inspector_dec_width', 'btn_inspector_inc_height'],
      'move': ['btn_inspector_move_left', 'btn_inspector_move_down'],
      'layer': ['btn_inspector_send_to_back', 'btn_inspector_bring_to_front'],
    };

    void expectTouchTarget(WidgetTester tester, String key) {
      final s = tester.getSize(find.byKey(Key(key)));
      expect(s.width, greaterThanOrEqualTo(48), reason: key);
      expect(s.height, greaterThanOrEqualTo(48), reason: key);
    }

    for (final size in const [Size(320, 640), Size(844, 390)]) {
      testWidgets('toolbar and tabbed inspector keep 48 dp targets at $size', (
        tester,
      ) async {
        await _setView(tester, size);
        final manager = _manager(standard);
        manager.toggleEditMode(true);
        manager.selectWidget('alt');
        await tester.pumpWidget(_app(manager));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (final key in [
          'btn_add_widget',
          'btn_done_editing',
          'btn_layer_selector',
          'btn_inspector_config',
          'btn_inspector_delete',
          'btn_inspector_close',
        ]) {
          expectTouchTarget(tester, key);
        }
        for (final entry in sectionKeys.entries) {
          await tester.tap(find.byKey(Key('inspector_tab_${entry.key}')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          for (final key in entry.value) {
            expectTouchTarget(tester, key);
          }
        }
      });
    }

    testWidgets('wide inspector shows all control groups at once', (tester) async {
      await _setView(tester, const Size(800, 1280)); // tall tablet: full-width dock
      final manager = _manager(standard);
      manager.toggleEditMode(true);
      manager.selectWidget('alt');
      await tester.pumpWidget(_app(manager));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('inspector_tab_size')), findsNothing);
      for (final keys in sectionKeys.values) {
        for (final key in keys) {
          expect(find.byKey(Key(key)), findsOneWidget, reason: key);
        }
      }
    });

    testWidgets('portrait: inspector flips to the top for lower-half selections', (
      tester,
    ) async {
      await _setView(tester, const Size(390, 844));
      final manager = _manager(standard);
      manager.toggleEditMode(true);
      manager.selectWidget('alt'); // top half
      await tester.pumpWidget(_app(manager));
      await tester.pumpAndSettle();
      final toolbarTop = tester.getRect(find.byKey(const Key('edit_toolbar'))).top;
      var panel = tester.getRect(find.byKey(const Key('widget_inspector_panel')));
      expect(panel.bottom, lessThanOrEqualTo(toolbarTop));
      expect(panel.center.dy, greaterThan(422), reason: 'docked at the bottom');

      manager.selectWidget('vario'); // lower half
      await tester.pumpAndSettle();
      panel = tester.getRect(find.byKey(const Key('widget_inspector_panel')));
      expect(panel.center.dy, lessThan(422), reason: 'docked at the top');
      final vario = _rectOf(tester, 'vario');
      expect(panel.overlaps(vario.deflate(1)), isFalse);
    });

    testWidgets('wide canvas: edit chrome docks to the side away from selection', (
      tester,
    ) async {
      await _setView(tester, const Size(1280, 800));
      final manager = _manager(standard);
      manager.toggleEditMode(true);
      manager.selectWidget('alt'); // left side of the canvas
      await tester.pumpWidget(_app(manager));
      await tester.pumpAndSettle();
      var panel = tester.getRect(find.byKey(const Key('widget_inspector_panel')));
      expect(panel.width, lessThanOrEqualTo(kEditChromeMaxWidth));
      expect(panel.left, greaterThan(640), reason: 'docked right');
      final toolbar = tester.getRect(find.byKey(const Key('edit_toolbar')));
      expect(toolbar.width, lessThanOrEqualTo(kEditChromeMaxWidth));

      manager.updateWidgetPlacement(
        manager.activeScreen.widgets[1].copyWith(x: 12),
      );
      await tester.pumpAndSettle();
      panel = tester.getRect(find.byKey(const Key('widget_inspector_panel')));
      expect(panel.right, lessThan(640), reason: 'docked left');
      expect(tester.takeException(), isNull);
    });

    testWidgets('Tall/Wide switch creates, edits and deletes a wide variant', (
      tester,
    ) async {
      await _setView(tester, const Size(500, 900));
      final manager = _manager(standard);
      manager.toggleEditMode(true);
      await tester.pumpWidget(_app(manager));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn_variant_wide')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('btn_copy_from_tall')));
      await tester.pumpAndSettle();
      expect(manager.activeScreen.hasWideVariant, isTrue);
      expect(manager.editMode.editedVariant, LayoutVariant.wide);
      expect(find.byKey(const Key('letterbox_preview')), findsOneWidget);

      manager.moveWidget('alt', 3, 0);
      await tester.pumpAndSettle();
      expect(manager.activeScreen.wideWidgets![1].x, 3);
      expect(manager.activeScreen.widgets[1].x, 0);

      await tester.tap(find.byKey(const Key('btn_variant_delete_wide')));
      await tester.pumpAndSettle();
      expect(manager.activeScreen.hasWideVariant, isFalse);
      expect(manager.editMode.editedVariant, LayoutVariant.tall);
    });

    testWidgets('selected widget is elevated and restored after deselect', (
      tester,
    ) async {
      await _setView(tester, const Size(400, 800));
      final manager = _manager(standard);
      manager.toggleEditMode(true);
      await tester.pumpWidget(_app(manager));
      await tester.pumpAndSettle();
      List<String> order() => tester
          .widgetList<Positioned>(find.byWidgetPredicate(
            (w) => w is Positioned && w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.startsWith('positioned_'),
          ))
          .map((p) => (p.key! as ValueKey<String>).value)
          .toList();
      manager.selectWidget('map');
      await tester.pumpAndSettle();
      expect(order().last, 'positioned_map');
      manager.selectWidget(null);
      await tester.pumpAndSettle();
      expect(order().first, 'positioned_map');
    });
  });

  group('Cockpit tokens', () {
    testWidgets('edit transitions are skipped when animations are disabled', (
      tester,
    ) async {
      late Duration enabled;
      late Duration disabled;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              enabled = CockpitTokens.transitionFor(context);
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: Builder(
                  builder: (context) {
                    disabled = CockpitTokens.transitionFor(context);
                    return const SizedBox();
                  },
                ),
              );
            },
          ),
        ),
      );
      expect(enabled, CockpitTokens.editTransition);
      expect(disabled, Duration.zero);
    });

    testWidgets('instrument digits use the bundled font with tabular figures', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 200,
            height: 120,
            child: NumericTextWidget(
              label: 'Alt',
              value: '1234',
              unit: 'm',
              style: NumericWidgetStyle.minimalistText,
            ),
          ),
        ),
      );
      final text = tester.widget<Text>(find.text('1234'));
      expect(text.style!.fontFamily, CockpitTokens.instrumentFont);
      expect(text.style!.fontFeatures, contains(const FontFeature.tabularFigures()));
      expect(tester.takeException(), isNull);
    });
  });
}
