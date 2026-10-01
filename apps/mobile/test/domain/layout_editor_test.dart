import 'package:brandyfly/domain/models/ui_config.dart';
import 'package:brandyfly/domain/models/widget_catalog.dart';
import 'package:brandyfly/domain/use_cases/layout_editor.dart';
import 'package:flutter_test/flutter_test.dart';

WidgetPlacementModel _p(
  String id,
  WidgetType type,
  int x,
  int y,
  int w,
  int h,
) => WidgetPlacementModel(id: id, type: type, x: x, y: y, w: w, h: h);

void main() {
  const editor = LayoutEditor();
  const phone = CellGeometry(390 / 16, 844 / 32);

  final base = [
    _p('map', WidgetType.map, 0, 0, 16, 32),
    _p('alt', WidgetType.altitude, 2, 2, 4, 4),
    _p('btn', WidgetType.mapRecenter, 12, 26, 3, 3),
  ];

  group('LayoutEditor bounds', () {
    test('move clamps to grid edges', () {
      var list = editor.move(base, 'alt', -10, -10);
      expect(list[1].x, 0);
      expect(list[1].y, 0);
      list = editor.move(list, 'alt', 100, 100);
      expect(list[1].x, 12);
      expect(list[1].y, 28);
    });

    test('resize respects type minimum and canvas edge', () {
      var list = editor.resize(base, 'alt', -10, -10);
      expect(list[1].w, 1);
      expect(list[1].h, 1);
      list = editor.resize(list, 'alt', 100, 100);
      expect(list[1].x + list[1].w, 16);
      expect(list[1].y + list[1].h, 32);
      expect(list[1].x, 2, reason: 'resize must not shift the widget');
    });

    test('vario bar cannot shrink below 1x4', () {
      final list = editor.resize(
        [_p('v', WidgetType.varioBar, 0, 0, 3, 16)],
        'v',
        -5,
        -20,
      );
      expect(list.first.w, 1);
      expect(list.first.h, 4);
    });

    test('update clamps out-of-range placements', () {
      final list = editor.update(
        base,
        base[1].copyWith(x: 15, y: -3, w: 40, h: 0),
      );
      expect(list[1].w, 16);
      expect(list[1].x, 0);
      expect(list[1].y, 0);
      expect(list[1].h, 1);
    });

    test('interactive widgets keep a 48 dp touch target', () {
      final list = editor.resize(base, 'btn', -5, -5, geometry: phone);
      final btn = list[2];
      expect(btn.w * phone.cellWidth, greaterThanOrEqualTo(48));
      expect(btn.h * phone.cellHeight, greaterThanOrEqualTo(48));
      expect(btn.w, 2);
      expect(btn.h, 2);
    });

    test('isBelowTouchTarget and fixTouchSize', () {
      final small = [_p('b', WidgetType.mapZoomIn, 0, 0, 1, 1)];
      expect(editor.isBelowTouchTarget(small.first, phone), isTrue);
      final fixed = editor.fixTouchSize(small, 'b', phone);
      expect(editor.isBelowTouchTarget(fixed.first, phone), isFalse);
      expect(
        editor.isBelowTouchTarget(base[1], phone),
        isFalse,
        reason: 'non-interactive widgets are never flagged',
      );
    });
  });

  group('LayoutEditor presets', () {
    test('preset keeps top-left when it fits', () {
      final list = editor.applyPreset(base, 'alt', SizePreset.l);
      expect(list[1].x, 2);
      expect(list[1].y, 2);
      expect(list[1].w, 8);
      expect(list[1].h, 5);
    });

    test('preset shifts inward only as needed', () {
      final start = [_p('alt', WidgetType.altitude, 14, 30, 2, 2)];
      final list = editor.applyPreset(start, 'alt', SizePreset.l);
      expect(list.first.x, 8);
      expect(list.first.y, 27);
      expect(list.first.w, 8);
      expect(list.first.h, 5);
    });

    test('Full preset of map fills canvas', () {
      final start = [_p('m', WidgetType.map, 4, 4, 8, 8)];
      final list = editor.applyPreset(start, 'm', SizePreset.full);
      expect(list.first.x, 0);
      expect(list.first.y, 0);
      expect(list.first.w, 16);
      expect(list.first.h, 32);
    });

    test('undefined preset is a no-op', () {
      final list = editor.applyPreset(base, 'btn', SizePreset.full);
      expect(identical(list, base), isTrue);
    });
  });

  group('LayoutEditor no-op detection', () {
    test('operations without effect return identical list', () {
      expect(identical(editor.move(base, 'alt', 0, 0), base), isTrue);
      expect(identical(editor.move(base, 'map', 1, 1), base), isTrue);
      expect(identical(editor.move(base, 'nope', 1, 0), base), isTrue);
      expect(identical(editor.resize(base, 'map', 1, 1), base), isTrue);
      expect(identical(editor.bringToFront(base, 'btn'), base), isTrue);
      expect(identical(editor.sendToBack(base, 'map'), base), isTrue);
      expect(identical(editor.remove(base, 'nope'), base), isTrue);
      expect(identical(editor.update(base, base[1]), base), isTrue);
    });
  });

  group('LayoutEditor add / remove / reorder', () {
    test('map-like widgets are added to the back at full size', () {
      final list = editor.add(base, WidgetType.thermalMap, 'tm');
      expect(list.first.id, 'tm');
      expect(list.first.w, 16);
      expect(list.first.h, 32);
    });

    test('instruments are added to the front at the first free slot', () {
      final list = editor.add(base, WidgetType.speed, 'spd');
      final added = list.last;
      expect(added.id, 'spd');
      expect(added.w, 4);
      expect(added.h, 4);
      // (0,0) overlaps 'alt' at (2,2); first free slot scanning rows is (6,0).
      expect(added.x, 6);
      expect(added.y, 0);
    });

    test('map controls are added with auto target', () {
      final list = editor.add(base, WidgetType.mapZoomRocker, 'r');
      expect(list.last.effectiveMapControlTarget, kAutoMapTarget);
      expect(list.last.type, WidgetType.mapZoomRocker);
    });

    test('add falls back to origin when grid is full', () {
      final full = [_p('a', WidgetType.altitude, 0, 0, 16, 32)];
      final list = editor.add(full, WidgetType.speed, 's');
      expect(list.last.x, 0);
      expect(list.last.y, 0);
    });

    test('reorder operations', () {
      expect(editor.bringToFront(base, 'map').last.id, 'map');
      expect(editor.bringForward(base, 'map')[1].id, 'map');
      expect(editor.sendBackward(base, 'btn')[1].id, 'btn');
      expect(editor.sendToBack(base, 'btn').first.id, 'btn');
      expect(editor.remove(base, 'alt').map((w) => w.id), ['map', 'btn']);
    });

    test('copyForVariant duplicates ids, sizes and order', () {
      final wide = editor.copyForVariant(base);
      expect(wide, base);
    });
  });
}
