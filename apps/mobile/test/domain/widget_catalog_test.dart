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
  });
}
