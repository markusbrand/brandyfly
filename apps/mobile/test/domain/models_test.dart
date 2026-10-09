import 'dart:convert';

import 'package:brandyfly/domain/models/cockpit_telemetry.dart';
import 'package:brandyfly/domain/models/size_tier.dart';
import 'package:brandyfly/domain/models/ui_config.dart';
import 'package:brandyfly/domain/models/widget_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Domain models', () {
    test('WidgetPlacementModel JSON round-trip keeps map control fields', () {
      const p = WidgetPlacementModel(
        id: 'c1',
        type: WidgetType.mapZoomRocker,
        x: 3,
        y: 4,
        w: 3,
        h: 6,
        mapControlTarget: 'w_map',
      );
      final restored = WidgetPlacementModel.fromJson(
        jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>,
      );
      expect(restored, p);
      expect(restored.effectiveMapControlTarget, 'w_map');
    });

    test('map built-in controls setting round-trips and defaults to auto', () {
      const map = WidgetPlacementModel(
        id: 'm',
        type: WidgetType.map,
        x: 0,
        y: 0,
        w: 16,
        h: 32,
      );
      expect(map.effectiveMapBuiltInControls, MapBuiltInControls.auto);
      final never = map.copyWith(mapBuiltInControls: MapBuiltInControls.never);
      final restored = WidgetPlacementModel.fromJson(never.toJson());
      expect(restored.effectiveMapBuiltInControls, MapBuiltInControls.never);
    });

    test('screen with unknown widget type skips only that widget', () {
      final screen = FlightScreenModel.fromJson({
        'id': 's',
        'name': 'S',
        'gridResolution': 16,
        'widgets': [
          {'id': 'a', 'type': 'altitude', 'x': 0, 'y': 0, 'w': 4, 'h': 4},
          {'id': 'b', 'type': 'hologram', 'x': 0, 'y': 0, 'w': 4, 'h': 4},
        ],
      });
      expect(screen.widgets.map((w) => w.id), ['a']);
    });

    test('wide variant round-trips and falls back to tall', () {
      const tall = [
        WidgetPlacementModel(
          id: 'a',
          type: WidgetType.altitude,
          x: 0,
          y: 0,
          w: 4,
          h: 4,
        ),
      ];
      const screen = FlightScreenModel(id: 's', name: 'S', widgets: tall);
      expect(screen.hasWideVariant, isFalse);
      expect(screen.widgetsFor(LayoutVariant.wide), same(tall));

      final withWide = screen.copyWith(
        wideWidgets: [tall.first.copyWith(x: 8)],
      );
      final restored = FlightScreenModel.fromJson(
        jsonDecode(jsonEncode(withWide.toJson())) as Map<String, dynamic>,
      );
      expect(restored.hasWideVariant, isTrue);
      expect(restored.widgetsFor(LayoutVariant.wide).first.x, 8);
      expect(restored.widgetsFor(LayoutVariant.tall).first.x, 0);
      expect(restored.copyWith(clearWideWidgets: true).hasWideVariant, isFalse);
    });

    test('UIConfig encodes current schema version', () {
      final json =
          jsonDecode(UIConfig.defaultConfig().encodeJson())
              as Map<String, dynamic>;
      expect(json['schemaVersion'], GridSpec.schemaVersion);
      expect(UIConfig.storedSchemaVersion(json), GridSpec.schemaVersion);
      expect(
        UIConfig.storedSchemaVersion({
          'screens': [
            {'gridResolution': 8},
          ],
        }),
        2,
      );
      expect(UIConfig.storedSchemaVersion({'screens': []}), 1);
    });

    test('default configuration fits the 16x32 grid', () {
      for (final screen in UIConfig.defaultConfig().screens) {
        for (final w in screen.widgets) {
          expect(w.x + w.w, lessThanOrEqualTo(GridSpec.columns), reason: w.id);
          expect(w.y + w.h, lessThanOrEqualTo(GridSpec.rows), reason: w.id);
        }
      }
    });
  });

  group('Widget catalog', () {
    test('every widget type has a complete spec', () {
      for (final type in WidgetType.values) {
        final spec = widgetCatalog[type];
        expect(spec, isNotNull, reason: 'missing catalog entry for $type');
        expect(spec!.presets, isNotEmpty, reason: '$type has no presets');
        for (final size in [
          spec.minSize,
          spec.defaultSize,
          ...spec.presets.values,
        ]) {
          expect(size.w, inInclusiveRange(1, GridSpec.columns));
          expect(size.h, inInclusiveRange(1, GridSpec.rows));
          expect(size.w, greaterThanOrEqualTo(spec.minSize.w));
          expect(size.h, greaterThanOrEqualTo(spec.minSize.h));
        }
      }
    });

    test('only map controls are interactive', () {
      for (final type in WidgetType.values) {
        expect(specFor(type).interactive, type.isMapControl, reason: '$type');
      }
    });

    test('interactive minimum grows to reach 48 dp', () {
      const phone = CellGeometry(390 / 16, 844 / 32); // ~24.4 x 26.4
      final min = effectiveMinSize(WidgetType.mapRecenter, geometry: phone);
      expect(min.w * phone.cellWidth, greaterThanOrEqualTo(48));
      expect(min.h * phone.cellHeight, greaterThanOrEqualTo(48));
      expect(min, const GridSize(2, 2));

      const landscape = CellGeometry(844 / 16, 390 / 32); // ~52.8 x 12.2
      expect(
        effectiveMinSize(WidgetType.mapRecenter, geometry: landscape),
        const GridSize(1, 4),
      );
      // Non-interactive widgets are unaffected.
      expect(
        effectiveMinSize(WidgetType.altitude, geometry: phone),
        const GridSize(1, 1),
      );
    });

    test('GridSpec.cellsForTouchTarget handles degenerate input', () {
      expect(GridSpec.cellsForTouchTarget(0), 1);
      expect(GridSpec.cellsForTouchTarget(double.infinity), 1);
      expect(GridSpec.cellsForTouchTarget(48), 1);
      expect(GridSpec.cellsForTouchTarget(24), 2);
    });
  });

  group('Size tiers and canvas shape', () {
    test('tier follows shortest rendered side', () {
      expect(sizeTierFor(30, 200), SizeTier.tiny);
      expect(sizeTierFor(39.9, 39.9), SizeTier.tiny);
      expect(sizeTierFor(40, 79), SizeTier.compact);
      expect(sizeTierFor(80, 80), SizeTier.regular);
      expect(sizeTierFor(double.infinity, double.infinity), SizeTier.regular);
    });

    test('canvas shape is wide only when width > height', () {
      expect(canvasShapeFor(390, 844), CanvasShape.tall);
      expect(canvasShapeFor(500, 500), CanvasShape.tall);
      expect(canvasShapeFor(844, 390), CanvasShape.wide);
    });
  });

  group('CockpitTelemetry', () {
    test('fromMap parses legacy telemetry map with defaults', () {
      final t = CockpitTelemetry.fromMap({
        'altitude': 1000,
        'climb': -2.5,
        'history': [1, 2, 3],
        'latitude': 47.0,
        'longitude': 13.0,
      });
      expect(t.altitude, 1000.0);
      expect(t.climb, -2.5);
      expect(t.speed, 42.5);
      expect(t.history, [1.0, 2.0, 3.0]);
      expect(t.pilotPosition, isNotNull);
      expect(t.effectiveHeading, 0.0);
      expect(t.windDir, isNull, reason: 'wind is never fabricated');
      expect(t.windSpeed, isNull);
      expect(t.hasWind, isFalse);
    });
  });
}
