import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/cockpit_telemetry.dart';
import '../../../../domain/models/size_tier.dart';
import '../../../../domain/models/ui_config.dart';
import '../../../../services/airspace_service.dart';
import '../../../../widgets/flight/airspace_side_cut_widget.dart';
import '../../../core/rebuild_probe.dart';
import '../../../core/value_selector.dart';
import '../../instruments/views/altitude_sparkline_chart.dart';
import '../../instruments/views/numeric_text_widget.dart';
import '../../instruments/views/thermal_map_adapter.dart';
import '../../instruments/views/thermal_map_widget.dart';
import '../../instruments/views/vario_lift_sink_bar.dart';
import '../../instruments/views/wind_direction_widget.dart';
import '../../map/views/map_control_widgets.dart';
import '../../map/views/map_widget.dart';

/// Renders the content of one placed widget, subscribing only to the
/// telemetry fields it displays.
///
/// Numeric values are selected as rounded integers at display precision so a
/// telemetry tick neither allocates strings nor rebuilds unchanged widgets.
class FlightWidgetContent extends StatelessWidget {
  const FlightWidgetContent({
    super.key,
    required this.model,
    required this.telemetry,
    required this.tier,
    this.mapControlTarget,
    this.showBuiltInMapControls = true,
  });

  final WidgetPlacementModel model;
  final ValueListenable<CockpitTelemetry> telemetry;
  final SizeTier tier;

  /// Resolved target map id for map control widgets.
  final String? mapControlTarget;

  /// For map widgets: whether built-in HUD buttons are shown.
  final bool showBuiltInMapControls;

  String get _probeKey => 'instrument:${model.id}';

  Widget _numeric<T>({
    required T Function(CockpitTelemetry t) select,
    required String Function(T v) format,
    required String label,
    required String unit,
  }) {
    return ValueSelector<CockpitTelemetry, T>(
      listenable: telemetry,
      select: select,
      builder: (context, v) {
        RebuildProbe.tick(_probeKey);
        return NumericTextWidget(
          label: label,
          value: format(v),
          unit: unit,
          style: model.effectiveNumericStyle,
          tier: tier,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (model.type) {
      case WidgetType.altitude:
        return _numeric<int>(
          select: (t) => t.altitude.round(),
          format: (v) => '$v',
          label: 'Altitude',
          unit: 'm',
        );
      case WidgetType.speed:
        return _numeric<int>(
          select: (t) => (t.speed * 10).round(),
          format: (v) => (v / 10).toStringAsFixed(1),
          label: 'Speed',
          unit: 'km/h',
        );
      case WidgetType.glide:
        return _numeric<int>(
          select: (t) => (t.glide * 10).round(),
          format: (v) => (v / 10).toStringAsFixed(1),
          label: 'Glide',
          unit: 'L/D',
        );
      case WidgetType.hag:
        return _numeric<int?>(
          select: (t) => t.hag?.round(),
          format: (v) => v != null ? '$v' : '---',
          label: 'HAG',
          unit: 'm AGL',
        );
      case WidgetType.windDirection:
        return ValueSelector<CockpitTelemetry, (int?, int?, bool)>(
          listenable: telemetry,
          select: (t) => (
            t.windDir?.round(),
            t.windSpeed == null ? null : (t.windSpeed! * 10).round(),
            t.windStale,
          ),
          builder: (context, v) {
            RebuildProbe.tick(_probeKey);
            return WindDirectionWidget(
              directionDegrees: v.$1?.toDouble(),
              speedKmH: v.$2 == null ? null : v.$2! / 10,
              isStale: v.$3,
              style: model.effectiveWindStyle,
              tier: tier,
            );
          },
        );
      case WidgetType.varioBar:
        return ValueSelector<CockpitTelemetry, int>(
          listenable: telemetry,
          select: (t) => (t.climb * 10).round(),
          builder: (context, v) {
            RebuildProbe.tick(_probeKey);
            return VarioLiftSinkBar(
              climbRateMs: v / 10,
              style: model.effectiveVarioStyle,
              tier: tier,
            );
          },
        );
      case WidgetType.altitudeChart:
        return ValueSelector<CockpitTelemetry, List<double>>(
          listenable: telemetry,
          select: (t) => t.history,
          equals: identical,
          builder: (context, history) {
            RebuildProbe.tick(_probeKey);
            return AltitudeSparklineChart(
              history: history,
              style: model.effectiveAltitudeChartStyle,
              tier: tier,
            );
          },
        );
      case WidgetType.map:
        // The map subscribes to telemetry itself (motion loop, native track
        // layers, HUD text); it is not rebuilt on every telemetry tick.
        RebuildProbe.tick(_probeKey);
        return MapWidget(
          key: ValueKey('map_widget_${model.id}'),
          cameraId: model.id,
          showBuiltInControls: showBuiltInMapControls,
          style: model.effectiveMapStyle,
          orientation: model.effectiveMapOrientation,
          showAirspace: model.effectiveMapShowAirspace,
          showThermals: model.effectiveMapShowThermals,
          thermalSeason: model.effectiveMapThermalSeason,
          thermalTimeOfDay: model.effectiveMapThermalTimeOfDay,
          thermalOpacity: model.effectiveMapThermalOpacity,
          showTrack: model.effectiveMapShowTrack,
          showContours: model.effectiveMapShowContours,
          initialZoom: model.effectiveMapZoomLevel,
          telemetry: telemetry,
          mapTrackHistoryMinutes: model.effectiveMapTrackHistoryMinutes,
          mapTrackShowOlderTail: model.effectiveMapTrackShowOlderTail,
        );
      case WidgetType.thermalMap:
        return ValueSelector<CockpitTelemetry, (int, int, int, int, int, bool)>(
          listenable: telemetry,
          select: (t) => (
            t.thermal.revision,
            t.altitude.round(),
            (t.speed * 10).round(),
            (t.climb * 10).round(),
            t.effectiveHeading.round(),
            t.hasSource,
          ),
          builder: (context, v) {
            RebuildProbe.tick(_probeKey);
            return _LiveThermalMap(model: model, telemetry: telemetry.value);
          },
        );
      case WidgetType.airspaceSideCut:
        return ValueListenableBuilder<CockpitTelemetry>(
          valueListenable: telemetry,
          builder: (context, t, _) {
            RebuildProbe.tick(_probeKey);
            final airspaceService = Provider.of<AirspaceService?>(context);
            final lat = t.latitude ?? 47.53;
            final lon = t.longitude ?? 13.68;
            final forwardBlocks = airspaceService?.getForwardAirspaces(
                  lat: lat,
                  lon: lon,
                  altitudeMsl: t.altitude,
                  headingDeg: t.effectiveHeading,
                  glideRatio: t.glide.clamp(1.0, 30.0),
                ) ??
                const [];
            final hag = t.hag ?? 300.0;
            return AirspaceSideCutWidget(
              aircraftAltitudeMsl: t.altitude,
              groundspeedMps: t.speed / 3.6,
              headingDeg: t.effectiveHeading,
              glideRatio: t.glide.clamp(1.0, 30.0),
              terrainElevationMsl: (t.altitude - hag).clamp(0.0, 6000.0),
              forwardBlocks: forwardBlocks,
            );
          },
        );
      case WidgetType.mapZoomIn:
      case WidgetType.mapZoomOut:
      case WidgetType.mapZoomRocker:
      case WidgetType.mapRecenter:
        return MapControlWidget(
          placementId: model.id,
          type: model.type,
          targetMapId: mapControlTarget,
        );
    }
  }
}

/// Thermal map fed by the live thermal assistant state. Holds the projection
/// adapter so unchanged track data is not re-projected on every rebuild.
class _LiveThermalMap extends StatefulWidget {
  const _LiveThermalMap({required this.model, required this.telemetry});

  final WidgetPlacementModel model;
  final CockpitTelemetry telemetry;

  @override
  State<_LiveThermalMap> createState() => _LiveThermalMapState();
}

class _LiveThermalMapState extends State<_LiveThermalMap> {
  final ThermalMapAdapter _adapter = ThermalMapAdapter();

  @override
  Widget build(BuildContext context) {
    final t = widget.telemetry;
    final model = widget.model;
    final preview = !t.hasSource;
    if (!preview) {
      _adapter.update(
        t.thermal,
        pilotLat: t.latitude,
        pilotLon: t.longitude,
        historySeconds: model.effectiveThermalMapHistorySeconds,
      );
    }
    return ThermalMapWidget(
      style: model.effectiveThermalMapStyle,
      showCore: model.effectiveThermalMapShowCore,
      historySeconds: model.effectiveThermalMapHistorySeconds,
      altitudeM: t.altitude,
      speedKmh: t.speed,
      climbRateMs: t.climb,
      headingDeg: t.effectiveHeading,
      windDirDeg: t.windDir,
      windSpeedKmh: t.windSpeed,
      trackPoints: preview ? null : _adapter.points,
      coreOffset: preview ? null : _adapter.core,
      referenceTime: preview ? null : t.thermal.timestamp,
      preview: preview,
    );
  }
}
