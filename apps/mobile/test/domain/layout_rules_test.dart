import 'dart:math';

import 'package:brandyfly/domain/models/ui_config.dart';
import 'package:brandyfly/domain/models/widget_catalog.dart';
import 'package:brandyfly/domain/use_cases/alignment_detector.dart';
import 'package:brandyfly/domain/use_cases/layout_migrator.dart';
import 'package:brandyfly/domain/use_cases/map_control_resolver.dart';
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

Map<String, dynamic> _w(String id, String type, int x, int y, int w, int h) =>
    {'id': id, 'type': type, 'x': x, 'y': y, 'w': w, 'h': h};

void main() {
  group('LayoutMigrator', () {
    test('8-column default screen (R=8) maps y by 4 and x by 2', () {
      final out = LayoutMigrator.migrateWidgets([
        _w('map', 'map', 0, 0, 8, 8),
        _w('alt', 'altitude', 0, 0, 2, 2),
        _w('spd', 'speed', 0, 2, 2, 2),
        _w('vario', 'varioBar', 0, 4, 2, 4),
        _w('wind', 'windDirection', 6, 0, 2, 2),
      ], 8);
      expect(out[0], containsPair('w', 16));
      expect(out[0], containsPair('h', 32));
      expect(out[2]['y'], 8);
      expect(out[2]['h'], 8);
      expect(out[3]['y'], 16);
      expect(out[3]['h'], 16);
      expect(out[4]['x'], 12);
      expect(out[4]['w'], 4);
    });

    test('8-column screen with R=12 maps rows proportionally', () {
      final out = LayoutMigrator.migrateWidgets([
        _w('a', 'altitude', 0, 0, 4, 4),
        _w('b', 'speed', 0, 4, 4, 1),
        _w('c', 'glide', 4, 10, 4, 2),
      ], 8);
      // R = 12 -> factor 32/12.
      expect(out[0]['y'], 0);
      expect(out[0]['h'], 11); // round(4*32/12)=11
      expect(out[1]['y'], 11);
      expect(out[1]['h'], 2); // round(5*32/12)=13 - 11
      expect(out[2]['y'], 27); // round(10*32/12)=27
      expect(out[2]['h'], 5); // 32 - 27
    });

    test('legacy 4-column screen is scaled to 8 then mapped to 16x32', () {
      final screen = FlightScreenModel.fromJson({
        'id': 'legacy',
        'name': 'Legacy',
        'widgets': [_w('w', 'altitude', 1, 2, 2, 1)],
      });
      // 4-col (1,2,2,1) -> 8-col (2,4,4,2), R=8 -> (4,16,8,8)
      final w = screen.widgets.single;
      expect([w.x, w.y, w.w, w.h], [4, 16, 8, 8]);
      expect(screen.gridResolution, 16);
    });

    test('16-column screens are only clamped', () {
      final out = LayoutMigrator.migrateWidgets([
        _w('a', 'altitude', 3, 5, 2, 2),
        _w('b', 'varioBar', 15, 30, 4, 1),
      ], 16);
      expect([out[0]['x'], out[0]['y'], out[0]['w'], out[0]['h']], [3, 5, 2, 2]);
      expect([out[1]['x'], out[1]['y'], out[1]['w'], out[1]['h']], [
        12,
        28,
        4,
        4,
      ]);
    });

    test('malformed and unknown widgets are dropped', () {
      final out = LayoutMigrator.migrateWidgets([
        'garbage',
        {'id': 'x', 'type': 'altitude', 'x': '1', 'y': 0, 'w': 1, 'h': 1},
        _w('u', 'unknownType', 0, 0, 1, 1),
        _w('ok', 'speed', 0, 0, 1, 1),
      ], 8);
      expect(out.map((w) => w['id']), ['ok']);
    });

    test('default 8-column screens migrate within bounds', () {
      final legacyDefaults = [
        [
          _w('m', 'map', 0, 0, 8, 8),
          _w('v', 'varioBar', 0, 0, 2, 8),
          _w('a', 'altitude', 2, 0, 6, 2),
        ],
        [
          _w('t', 'thermalMap', 0, 0, 8, 8),
          _w('w', 'windDirection', 2, 0, 6, 6),
          _w('a', 'altitude', 2, 6, 6, 2),
        ],
      ];
      for (final screen in legacyDefaults) {
        final out = LayoutMigrator.migrateWidgets(screen, 8);
        expect(out.length, screen.length);
        for (final w in out) {
          expect((w['x'] as int) + (w['w'] as int), lessThanOrEqualTo(16));
          expect((w['y'] as int) + (w['h'] as int), lessThanOrEqualTo(32));
        }
      }
    });

    test('fuzz: 500 random 8-column layouts stay in bounds and minimums', () {
      final rnd = Random(1234);
      final types = WidgetType.values;
      for (var i = 0; i < 500; i++) {
        final n = 1 + rnd.nextInt(8);
        final widgets = [
          for (var j = 0; j < n; j++)
            _w(
              'w$j',
              types[rnd.nextInt(types.length)].name,
              rnd.nextInt(10) - 1,
              rnd.nextInt(24) - 1,
              rnd.nextInt(10),
              rnd.nextInt(18),
            ),
        ];
        final res = rnd.nextBool() ? 8 : 4;
        final out = LayoutMigrator.migrateWidgets(widgets, res);
        expect(out.length, n);
        for (final w in out) {
          final type = widgetTypeFromName(w['type'])!;
          final min = specFor(type).minSize;
          final x = w['x'] as int, y = w['y'] as int;
          final ww = w['w'] as int, hh = w['h'] as int;
          expect(x, greaterThanOrEqualTo(0));
          expect(y, greaterThanOrEqualTo(0));
          expect(ww, greaterThanOrEqualTo(min.w));
          expect(hh, greaterThanOrEqualTo(min.h));
          expect(x + ww, lessThanOrEqualTo(16));
          expect(y + hh, lessThanOrEqualTo(32));
        }
      }
    });
  });

  group('AlignmentDetector', () {
    const detector = AlignmentDetector();

    test('edge alignment produces a vertical guide', () {
      final widgets = [
        _p('a', WidgetType.altitude, 2, 0, 4, 4),
        _p('b', WidgetType.speed, 2, 10, 3, 3),
      ];
      final result = detector.detect(widgets, 'b');
      expect(
        result.guides,
        contains(const AlignmentGuide(GuideAxis.vertical, 2)),
      );
      expect(result.overlaps, isEmpty);
    });

    test('center alignment uses fractional positions', () {
      final widgets = [
        _p('a', WidgetType.altitude, 0, 0, 5, 4), // center x 2.5
        _p('b', WidgetType.speed, 1, 10, 3, 3), // center x 2.5
      ];
      final result = detector.detect(widgets, 'b');
      expect(
        result.guides,
        contains(const AlignmentGuide(GuideAxis.vertical, 2.5)),
      );
    });

    test('overlaps exclude full-canvas background maps', () {
      final widgets = [
        _p('map', WidgetType.map, 0, 0, 16, 32),
        _p('a', WidgetType.altitude, 0, 0, 4, 4),
        _p('b', WidgetType.speed, 2, 2, 4, 4),
      ];
      final result = detector.detect(widgets, 'b');
      expect(result.overlaps, [const GridRect(2, 2, 2, 2)]);
    });

    test('non-full-size maps count as overlap', () {
      final widgets = [
        _p('map', WidgetType.map, 0, 0, 8, 8),
        _p('b', WidgetType.speed, 2, 2, 2, 2),
      ];
      expect(detector.detect(widgets, 'b').overlaps, hasLength(1));
    });

    test('unknown id yields empty result', () {
      expect(detector.detect(const [], 'x').isEmpty, isTrue);
    });
  });

  group('MapControlResolver', () {
    const resolver = MapControlResolver();

    test('auto target resolves to bottom-most map', () {
      final widgets = [
        _p('m1', WidgetType.map, 0, 0, 16, 32),
        _p('m2', WidgetType.map, 0, 0, 8, 8),
        _p('c', WidgetType.mapZoomIn, 0, 0, 2, 2, target: kAutoMapTarget),
      ];
      expect(resolver.resolveTarget(widgets, widgets[2]), 'm1');
      expect(resolver.mapsWithExternalControls(widgets), {'m1'});
    });

    test('explicit target among several maps', () {
      final widgets = [
        _p('m1', WidgetType.map, 0, 0, 16, 32),
        _p('m2', WidgetType.map, 0, 0, 8, 8),
        _p('c', WidgetType.mapZoomIn, 0, 0, 2, 2, target: 'm2'),
      ];
      expect(resolver.resolveTarget(widgets, widgets[2]), 'm2');
      expect(resolver.mapsWithExternalControls(widgets), {'m2'});
    });

    test('missing target and no map yield null', () {
      final orphan = _p('c', WidgetType.mapRecenter, 0, 0, 2, 2, target: 'gone');
      expect(resolver.resolveTarget([orphan], orphan), isNull);
      expect(resolver.isTargetMissing([orphan], orphan), isTrue);
      final auto = _p('c', WidgetType.mapRecenter, 0, 0, 2, 2);
      expect(resolver.resolveTarget([auto], auto), isNull);
      expect(resolver.isTargetMissing([auto], auto), isFalse);
    });

    test('thermal map is not a valid target', () {
      final widgets = [
        _p('t', WidgetType.thermalMap, 0, 0, 16, 32),
        _p('c', WidgetType.mapZoomIn, 0, 0, 2, 2, target: 't'),
      ];
      expect(resolver.resolveTarget(widgets, widgets[1]), isNull);
      expect(resolver.autoTargetId(widgets), isNull);
    });

    test('built-in visibility policy', () {
      final map = _p('m', WidgetType.map, 0, 0, 16, 32);
      expect(resolver.builtInControlsVisible(map, {}), isTrue);
      expect(resolver.builtInControlsVisible(map, {'m'}), isFalse);
      expect(
        resolver.builtInControlsVisible(
          map.copyWith(mapBuiltInControls: MapBuiltInControls.always),
          {'m'},
        ),
        isTrue,
      );
      expect(
        resolver.builtInControlsVisible(
          map.copyWith(mapBuiltInControls: MapBuiltInControls.never),
          {},
        ),
        isFalse,
      );
    });
  });
}
