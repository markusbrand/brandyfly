import 'package:brandyfly/domain/models/grid_spec.dart';
import 'package:brandyfly/domain/models/widget_catalog.dart';
import 'package:brandyfly/domain/models/widget_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WidgetCatalog AirspaceSideCut Tests', () {
    test('airspaceSideCut is defined in widgetCatalog with min 8x4 and presets', () {
      final spec = specFor(WidgetType.airspaceSideCut);
      expect(spec.minSize.w, 8);
      expect(spec.minSize.h, 4);
      expect(spec.defaultSize.w, 16);
      expect(spec.defaultSize.h, 8);
      expect(spec.presets[SizePreset.s], const GridSize(16, 6));
      expect(spec.presets[SizePreset.m], const GridSize(16, 8));
      expect(spec.presets[SizePreset.l], const GridSize(16, 12));
      expect(spec.presets[SizePreset.full], const GridSize(16, 32));
    });

    test('clampGridRect enforces minimum size of 8x4 for airspaceSideCut', () {
      const tooSmall = GridRect(0, 0, 4, 2);
      final clamped = clampGridRect(WidgetType.airspaceSideCut, tooSmall);
      expect(clamped.w, 8);
      expect(clamped.h, 4);
    });

    test('clampGridRect constrains within 16x32 bounds', () {
      const outOfBounds = GridRect(10, 30, 8, 4);
      final clamped = clampGridRect(WidgetType.airspaceSideCut, outOfBounds);
      expect(clamped.x + clamped.w, lessThanOrEqualTo(GridSpec.columns));
      expect(clamped.y + clamped.h, lessThanOrEqualTo(GridSpec.rows));
    });

    test('widgetTypeFromName parses airspaceSideCut correctly', () {
      expect(widgetTypeFromName('airspaceSideCut'), WidgetType.airspaceSideCut);
      expect(WidgetType.airspaceSideCut.displayName, 'Airspace profile');
    });

    test('thermalStats is defined in widgetCatalog with min 3x2 and presets', () {
      final spec = specFor(WidgetType.thermalStats);
      expect(spec.minSize.w, 3);
      expect(spec.minSize.h, 2);
      expect(spec.defaultSize.w, 6);
      expect(spec.defaultSize.h, 4);
      expect(spec.presets[SizePreset.s], const GridSize(4, 3));
      expect(spec.presets[SizePreset.m], const GridSize(6, 4));
      expect(spec.presets[SizePreset.l], const GridSize(8, 5));
      expect(spec.presets[SizePreset.full], const GridSize(16, 8));
      expect(widgetTypeFromName('thermalStats'), WidgetType.thermalStats);
      expect(WidgetType.thermalStats.displayName, 'Thermal stats');
    });

    test('flightTime is defined in widgetCatalog with min 3x2 and presets', () {
      final spec = specFor(WidgetType.flightTime);
      expect(spec.minSize.w, 3);
      expect(spec.minSize.h, 2);
      expect(spec.defaultSize.w, 4);
      expect(spec.defaultSize.h, 4);
      expect(spec.presets[SizePreset.s], const GridSize(3, 2));
      expect(spec.presets[SizePreset.m], const GridSize(4, 4));
      expect(spec.presets[SizePreset.l], const GridSize(8, 5));
      expect(spec.presets[SizePreset.full], const GridSize(16, 8));
      expect(widgetTypeFromName('flightTime'), WidgetType.flightTime);
      expect(WidgetType.flightTime.displayName, 'Flight time');

      const tooSmall = GridRect(0, 0, 1, 1);
      final clamped = clampGridRect(WidgetType.flightTime, tooSmall);
      expect(clamped.w, 3);
      expect(clamped.h, 2);
    });

    test('returnGlide is defined in widgetCatalog with min 4x3 and presets', () {
      final spec = specFor(WidgetType.returnGlide);
      expect(spec.minSize.w, 4);
      expect(spec.minSize.h, 3);
      expect(spec.defaultSize.w, 6);
      expect(spec.defaultSize.h, 4);
      expect(spec.presets[SizePreset.s], const GridSize(4, 3));
      expect(spec.presets[SizePreset.m], const GridSize(6, 4));
      expect(spec.presets[SizePreset.l], const GridSize(8, 5));
      expect(spec.presets[SizePreset.full], const GridSize(16, 8));
      expect(widgetTypeFromName('returnGlide'), WidgetType.returnGlide);
      expect(WidgetType.returnGlide.displayName, 'Return glide');

      const tooSmall = GridRect(0, 0, 2, 2);
      final clamped = clampGridRect(WidgetType.returnGlide, tooSmall);
      expect(clamped.w, 4);
      expect(clamped.h, 3);
    });
  });
}
