import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:maplibre/maplibre.dart';

import '../../../../models/flight_model.dart';
import '../../../../models/lat_lng.dart';
import 'track_geojson.dart';
import 'vario_track_palette.dart';

/// Owns the native MapLibre sources/layers for the flight overlays (track,
/// mock airspace, free-floating pilot marker) so they render in the same GL
/// frame as the base map.
///
/// The track is split into a periodically rebuilt window/tail and a small
/// head that is updated on every new fix, so per-fix work does not grow
/// with flight length.
class MapFlightLayers {
  MapFlightLayers({
    this.rebuildInterval = const Duration(seconds: 10),
    this.headRebuildThreshold = 120,
    DateTime Function()? clock,
    this.airspacePolygon = defaultMockAirspacePolygon,
  }) : _clock = clock ?? DateTime.now;

  static const String airspaceSourceId = 'bf-airspace';
  static const String airspaceFillLayerId = 'bf-airspace-fill';
  static const String airspaceLineLayerId = 'bf-airspace-line';
  static const String tailSourceId = 'bf-track-tail';
  static const String windowSourceId = 'bf-track-window';
  static const String headSourceId = 'bf-track-head';
  static const String pilotSourceId = 'bf-pilot';
  static const String pilotImageId = 'bf-pilot-arrow';

  /// Lowest overlay layer (thermal raster swaps go below it).
  static const String bottomLayerId = airspaceFillLayerId;

  /// Static mock airspace restriction polygon (Dachstein / Krippenstein).
  static const List<LatLng> defaultMockAirspacePolygon = [
    LatLng(47.550, 13.650),
    LatLng(47.560, 13.710),
    LatLng(47.535, 13.725),
    LatLng(47.510, 13.675),
  ];

  /// Max time between full window/tail rebuilds while new fixes arrive.
  final Duration rebuildInterval;

  /// Head size (points) that forces a full rebuild.
  final int headRebuildThreshold;

  final List<LatLng> airspacePolygon;
  final DateTime Function() _clock;

  StyleController? _style;
  bool _attached = false;

  // Configuration.
  bool _showTrack = true;
  int _historyMinutes = 10;
  bool _showOlderTail = true;
  bool _showAirspace = true;

  // Track state.
  List<FlightPoint> _points = const [];
  int _committed = 0; // points covered by window/tail sources
  int _sentHeadLength = 0;
  DateTime? _firstTs;
  DateTime? _lastTs;
  int _lastLength = 0;
  DateTime? _lastRebuild;
  bool _dirty = true;

  // Pilot state.
  String _pilotData = TrackGeoJson.empty;
  String? _sentPilotData;

  /// Number of full window/tail rebuilds (diagnostics / tests).
  int fullRebuilds = 0;

  /// Number of head-only updates (diagnostics / tests).
  int headUpdates = 0;

  bool get isAttached => _attached;
  int get committedPoints => _committed;

  /// Adds sources and layers to a freshly loaded [style]. Layers are
  /// inserted below [belowLayerId] (first label layer) and the pilot symbol
  /// on top.
  Future<void> attach(StyleController style, {String? belowLayerId}) async {
    _style = style;
    _attached = false;
    _dirty = true;
    try {
      final data = _buildFull();
      final polygon = _showAirspace
          ? TrackGeoJson.polygon(airspacePolygon)
          : TrackGeoJson.empty;
      await style.addSource(GeoJsonSource(id: airspaceSourceId, data: polygon));
      await style.addSource(GeoJsonSource(id: tailSourceId, data: data.tail));
      await style.addSource(
        GeoJsonSource(id: windowSourceId, data: data.window),
      );
      await style.addSource(GeoJsonSource(id: headSourceId, data: data.head));
      await style.addSource(GeoJsonSource(id: pilotSourceId, data: _pilotData));
      _sentPilotData = _pilotData;

      const round = {'line-cap': 'round', 'line-join': 'round'};
      final trackPaint = {
        'line-color': [
          'to-color',
          ['get', 'c'],
        ],
        'line-width': 3.5,
      };
      for (final layer in <StyleLayer>[
        const FillStyleLayer(
          id: airspaceFillLayerId,
          sourceId: airspaceSourceId,
          paint: {'fill-color': '#ef4444', 'fill-opacity': 0.14},
        ),
        const LineStyleLayer(
          id: airspaceLineLayerId,
          sourceId: airspaceSourceId,
          paint: {
            'line-color': '#ef4444',
            'line-opacity': 0.7,
            'line-width': 1.5,
          },
        ),
        LineStyleLayer(
          id: tailSourceId,
          sourceId: tailSourceId,
          layout: round,
          paint: {
            'line-color': VarioTrackPalette.toHex(VarioTrackPalette.tailColor),
            'line-opacity': 0.45,
            'line-width': 2.0,
          },
        ),
        LineStyleLayer(
          id: windowSourceId,
          sourceId: windowSourceId,
          layout: round,
          paint: trackPaint,
        ),
        LineStyleLayer(
          id: headSourceId,
          sourceId: headSourceId,
          layout: round,
          paint: trackPaint,
        ),
      ]) {
        await style.addLayer(layer, belowLayerId: belowLayerId);
      }
      await style.addLayer(
        const SymbolStyleLayer(
          id: pilotSourceId,
          sourceId: pilotSourceId,
          layout: {
            'icon-image': pilotImageId,
            'icon-size': 1 / _iconScale,
            'icon-rotate': ['get', 'r'],
            'icon-rotation-alignment': 'map',
            'icon-allow-overlap': true,
            'icon-ignore-placement': true,
          },
        ),
      );
      _attached = identical(_style, style);
      _dirty = false;
      // The icon is rasterized asynchronously; the symbol layer simply shows
      // nothing until it is available.
      unawaited(
        _addPilotImage(style).catchError(
          (Object e) => debugPrint('[MapFlightLayers] pilot icon failed: $e'),
        ),
      );
    } catch (e) {
      debugPrint('[MapFlightLayers] attach failed: $e');
    }
  }

  /// Forgets the style (it was replaced or the map disposed).
  void detach() {
    _style = null;
    _attached = false;
  }

  /// Updates visibility / history settings; rebuilds when changed.
  void configure({
    required bool showTrack,
    required int historyMinutes,
    required bool showOlderTail,
    required bool showAirspace,
  }) {
    final trackChanged =
        showTrack != _showTrack ||
        historyMinutes != _historyMinutes ||
        showOlderTail != _showOlderTail;
    final airspaceChanged = showAirspace != _showAirspace;
    _showTrack = showTrack;
    _historyMinutes = historyMinutes;
    _showOlderTail = showOlderTail;
    _showAirspace = showAirspace;
    if (trackChanged) _fullRebuild();
    if (airspaceChanged) {
      _send(
        airspaceSourceId,
        showAirspace
            ? TrackGeoJson.polygon(airspacePolygon)
            : TrackGeoJson.empty,
      );
    }
  }

  /// Feeds the current recorded track. Detects growth, resets and seeks by
  /// length and first/last timestamps (live lists are mutated in place).
  void updateTrack(List<FlightPoint> points) {
    final len = points.length;
    final first = len == 0 ? null : points.first.timestamp;
    final last = len == 0 ? null : points.last.timestamp;
    final grown =
        len > _lastLength &&
        first == _firstTs &&
        _lastLength > 0 &&
        (identical(points, _points) || _sameAt(points, _lastLength - 1));
    final unchanged =
        len == _lastLength && first == _firstTs && last == _lastTs;
    _points = points;
    _lastLength = len;
    _firstTs = first;
    _lastTs = last;
    if (unchanged && !_dirty) return;

    if (_dirty || !grown) {
      _fullRebuild();
      return;
    }
    final now = _clock();
    final lastRebuild = _lastRebuild;
    if (len - _committed > headRebuildThreshold ||
        lastRebuild == null ||
        now.difference(lastRebuild) >= rebuildInterval) {
      _fullRebuild();
      return;
    }
    _sendHead();
  }

  DateTime? _lastTsAt(int i) =>
      i >= 0 && i < _points.length ? _points[i].timestamp : null;

  bool _sameAt(List<FlightPoint> points, int i) =>
      i >= 0 && i < points.length && points[i].timestamp == _lastTsAt(i);

  /// Shows ([visible]) or hides the native pilot symbol.
  void updatePilot(
    LatLng position,
    double headingDeg, {
    required bool visible,
  }) {
    _pilotData = visible
        ? TrackGeoJson.point(position, headingDeg)
        : TrackGeoJson.empty;
    if (_pilotData == _sentPilotData) return;
    if (_send(pilotSourceId, _pilotData)) _sentPilotData = _pilotData;
  }

  ({String tail, String window, String head}) _buildFull() {
    final pts = _points;
    _committed = pts.length;
    _sentHeadLength = 0;
    _lastRebuild = _clock();
    fullRebuilds++;
    if (!_showTrack || pts.length < 2) {
      return (
        tail: TrackGeoJson.empty,
        window: TrackGeoJson.empty,
        head: TrackGeoJson.empty,
      );
    }
    final start = TrackGeoJson.windowStartIndex(pts, _historyMinutes);
    return (
      tail: _showOlderTail && start > 0
          ? TrackGeoJson.tail(pts, start)
          : TrackGeoJson.empty,
      window: TrackGeoJson.segments(pts, start, pts.length),
      head: TrackGeoJson.empty,
    );
  }

  void _fullRebuild() {
    final data = _buildFull();
    if (_style == null || !_attached) {
      _dirty = true;
      return;
    }
    var ok = _send(tailSourceId, data.tail);
    ok &= _send(windowSourceId, data.window);
    ok &= _send(headSourceId, data.head);
    _dirty = !ok;
  }

  void _sendHead() {
    final pts = _points;
    if (pts.length == _sentHeadLength) return;
    headUpdates++;
    final data = _showTrack
        ? TrackGeoJson.segments(pts, math.max(0, _committed - 1), pts.length)
        : TrackGeoJson.empty;
    if (_send(headSourceId, data)) {
      _sentHeadLength = pts.length;
    } else {
      _dirty = true;
    }
  }

  /// Sends source data; failures are logged and mark the state dirty so the
  /// next update retries with current data. Returns false when not sent.
  bool _send(String sourceId, String data) {
    final style = _style;
    if (style == null || !_attached) {
      _dirty = true;
      return false;
    }
    try {
      unawaited(
        style.updateGeoJsonSource(id: sourceId, data: data).catchError((
          Object e,
        ) {
          debugPrint('[MapFlightLayers] update $sourceId failed: $e');
          _dirty = true;
          if (sourceId == pilotSourceId) _sentPilotData = null;
        }),
      );
      return true;
    } catch (e) {
      debugPrint('[MapFlightLayers] update $sourceId failed: $e');
      _dirty = true;
      return false;
    }
  }

  static const double _iconScale = 3;
  static const double _iconLogical = 40;

  static Future<void> _addPilotImage(StyleController style) {
    const px = (_iconLogical * _iconScale);
    return style.addImageFromCanvas(
      id: pilotImageId,
      width: px.round(),
      height: px.round(),
      painter: (canvas) {
        canvas
          ..translate(px / 2, px / 2)
          ..scale(_iconScale);
        canvas.drawCircle(
          ui.Offset.zero,
          18,
          ui.Paint()..color = const ui.Color(0x2D18FFFF),
        );
        final path = ui.Path()
          ..moveTo(0, -11)
          ..lineTo(-8, 8)
          ..lineTo(0, 3)
          ..lineTo(8, 8)
          ..close();
        canvas.drawPath(
          path,
          ui.Paint()
            ..color = const ui.Color(0xDD000000)
            ..style = ui.PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
        canvas.drawPath(path, ui.Paint()..color = const ui.Color(0xFF18FFFF));
      },
    );
  }
}
