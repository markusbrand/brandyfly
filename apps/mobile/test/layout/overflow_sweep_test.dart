// Overflow sweep: every widget type, in every visual style, at its catalog
// minimum, each preset and full size, on three reference canvases, both in
// flight and in edit mode with the widget selected. Any layout exception
// (RenderFlex overflow, unbounded constraints, misplaced parent data) fails.
import 'package:brandyfly/domain/models/cockpit_telemetry.dart';
import 'package:brandyfly/domain/models/ui_config.dart';
import 'package:brandyfly/domain/models/widget_catalog.dart';
import 'package:brandyfly/services/screen_manager_service.dart';
import 'package:brandyfly/ui/features/flight_canvas/views/layout_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _canvases = [Size(390, 844), Size(844, 390), Size(1280, 800)];

/// Visual style variants per widget type (null = type has no style option).
List<WidgetPlacementModel Function(WidgetPlacementModel)> _styleVariants(
  WidgetType type,
) {
  if (type.isNumeric) {
    return [
      for (final s in NumericWidgetStyle.values)
        (p) => p.copyWith(numericStyle: s),
    ];
  }
  switch (type) {
    case WidgetType.windDirection:
      return [
        for (final s in WindWidgetStyle.values) (p) => p.copyWith(windStyle: s),
      ];
    case WidgetType.varioBar:
      return [
        for (final s in LiftSinkBarStyle.values)
          (p) => p.copyWith(varioStyle: s),
      ];
    case WidgetType.altitudeChart:
      return [
        for (final s in AltitudeChartStyle.values)
          (p) => p.copyWith(altitudeChartStyle: s),
      ];
    case WidgetType.map:
      return [
        for (final s in MapWidgetStyle.values) (p) => p.copyWith(mapStyle: s),
      ];
    case WidgetType.thermalMap:
      return [
        for (final s in ThermalMapStyle.values)
          (p) => p.copyWith(thermalMapStyle: s),
      ];
    default:
      return [(p) => p];
  }
}

Set<GridSize> _sizesFor(WidgetType type) {
  final spec = specFor(type);
  return {
    spec.minSize,
    spec.defaultSize,
    ...spec.presets.values,
    const GridSize(16, 32),
  };
}

String _styleName(WidgetPlacementModel p) =>
    (p.numericStyle ??
            p.windStyle ??
            p.varioStyle ??
            p.altitudeChartStyle ??
            p.mapStyle ??
            p.thermalMapStyle)
        ?.name ??
    'default';

void main() {
  final telemetry = ValueNotifier(
    const CockpitTelemetry(
      altitude: 12345,
      speed: 123.4,
      climb: -4.7,
      hag: 2345,
      windSpeed: 45.6,
    ),
  );

  for (final type in WidgetType.values) {
    for (final applyStyle in _styleVariants(type)) {
      final sample = applyStyle(
        WidgetPlacementModel(id: 'w', type: type, x: 0, y: 0, w: 1, h: 1),
      );
      testWidgets('overflow sweep: ${type.name} / ${_styleName(sample)}', (
        tester,
      ) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.view.devicePixelRatio = 1.0;

        for (final size in _sizesFor(type)) {
          final placement = sample.copyWith(w: size.w, h: size.h);
          final widgets = [
            // Map controls get a target map so the enabled path renders too.
            if (type.isMapControl)
              const WidgetPlacementModel(
                id: 'bg_map',
                type: WidgetType.map,
                x: 0,
                y: 0,
                w: 16,
                h: 32,
              ),
            placement,
          ];
          for (final canvas in _canvases) {
            for (final edit in [false, true]) {
              final manager = ScreenManagerService(
                initialConfig: UIConfig(
                  activeScreenId: 's',
                  screens: [FlightScreenModel(id: 's', name: 'S', widgets: widgets)],
                ),
              );
              if (edit) {
                manager.toggleEditMode(true);
                manager.selectWidget('w');
              }
              tester.view.physicalSize = canvas;
              await tester.pumpWidget(
                MaterialApp(
                  key: UniqueKey(),
                  home: Scaffold(
                    body: LayoutStrategyContainer(
                      screenManager: manager,
                      telemetry: telemetry,
                    ),
                  ),
                ),
              );
              await tester.pump();
              final error = tester.takeException();
              expect(
                error,
                isNull,
                reason:
                    '${type.name}/${_styleName(sample)} $size on $canvas '
                    '(${edit ? 'edit' : 'flight'})',
              );
              await tester.pumpWidget(const SizedBox());
              manager.dispose();
            }
          }
        }
      });
    }
  }
}
