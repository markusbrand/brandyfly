import 'dart:convert';

import 'package:brandyfly/models/flight_model.dart';
import 'package:brandyfly/models/lat_lng.dart';
import 'package:brandyfly/ui/features/map/layers/map_flight_layers.dart';
import 'package:brandyfly/ui/features/map/layers/track_geojson.dart';
import 'package:brandyfly/ui/features/map/layers/vario_track_palette.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/recording_style_controller.dart';

final _t0 = DateTime.utc(2026, 7, 1, 10);

List<FlightPoint> _flight(int n, {double Function(int i)? vario}) => [
  for (var i = 0; i < n; i++)
    FlightPoint(
      timestamp: _t0.add(Duration(seconds: i)),
      latitude: 47.5 + i * 0.0001,
      longitude: 13.6 + i * 0.0001,
      altitude: 1500,
      vario: vario?.call(i) ?? 1.0,
    ),
];

List<dynamic> _features(String geojson) =>
    (jsonDecode(geojson) as Map<String, dynamic>)['features'] as List;

int _vertexCount(String geojson) => _features(
  geojson,
).fold<int>(0, (n, f) => n + ((f['geometry']['coordinates'] as List).length));

void main() {
  group('TrackGeoJson', () {
    test('merges consecutive same-color segments with color property', () {
      final pts = _flight(7, vario: (i) => i < 4 ? 2.5 : -2.0);
      final f = _features(TrackGeoJson.segments(pts, 0, pts.length));
      expect(f, hasLength(2));
      expect(f[0]['properties']['c'], VarioTrackPalette.hexFor(2.5));
      expect(f[1]['properties']['c'], VarioTrackPalette.hexFor(-2.0));
      // Segments 1..3 (4 vertices), then 4..6 starting at point 3 (4 vertices).
      expect((f[0]['geometry']['coordinates'] as List).length, 4);
      expect((f[1]['geometry']['coordinates'] as List).length, 4);
    });

    test('window start applies the history window (0 = full flight)', () {
      final pts = [
        for (var m = 0; m <= 30; m++)
          FlightPoint(
            timestamp: _t0.add(Duration(minutes: m)),
            latitude: 47.5,
            longitude: 13.6 + m * 0.001,
            altitude: 1500,
            vario: 1,
          ),
      ];
      expect(TrackGeoJson.windowStartIndex(pts, 10), 20);
      expect(TrackGeoJson.windowStartIndex(pts, 0), 0);
      expect(TrackGeoJson.windowStartIndex(pts, 60), 0);
    });

    test('cached encoding produces identical GeoJSON', () {
      final pts = _flight(300, vario: (i) => (i % 17 - 8) / 2);
      final cache = TrackEncodingCache();
      expect(
        TrackGeoJson.segments(pts, 40, 250, cache: cache),
        TrackGeoJson.segments(pts, 40, 250),
      );
      expect(
        TrackGeoJson.tail(pts, 120, cache: cache),
        TrackGeoJson.tail(pts, 120),
      );
      // A different track resets the cache.
      final other = _flight(50, vario: (i) => -1);
      expect(
        TrackGeoJson.segments(other, 0, 50, cache: cache),
        TrackGeoJson.segments(other, 0, 50),
      );
    });

    test('hex colors match the vario palette', () {
      expect(VarioTrackPalette.hexFor(0.0), '#94a3b8');
      expect(VarioTrackPalette.hexFor(4.0), '#15803d');
      expect(VarioTrackPalette.hexFor(-4.0), '#991b1b');
    });
  });

  group('MapFlightLayers', () {
    late DateTime now;
    late RecordingStyleController style;
    late MapFlightLayers layers;

    setUp(() {
      now = _t0;
      style = RecordingStyleController();
      layers = MapFlightLayers(clock: () => now);
    });

    test('attach adds sources and layers below labels, pilot on top', () async {
      await layers.attach(style, belowLayerId: 'labels');
      expect(layers.isAttached, isTrue);
      expect(
        style.sourceData.keys,
        containsAll([
          MapFlightLayers.airspaceSourceId,
          MapFlightLayers.tailSourceId,
          MapFlightLayers.windowSourceId,
          MapFlightLayers.headSourceId,
          MapFlightLayers.pilotSourceId,
        ]),
      );
      for (final id in [
        MapFlightLayers.airspaceFillLayerId,
        MapFlightLayers.airspaceLineLayerId,
        MapFlightLayers.tailSourceId,
        MapFlightLayers.windowSourceId,
        MapFlightLayers.headSourceId,
      ]) {
        expect(style.layerBelow[id], 'labels', reason: id);
      }
      expect(style.layerBelow[MapFlightLayers.pilotSourceId], isNull);
      // Bottom-to-top order preserved.
      expect(style.layerIds, [
        MapFlightLayers.airspaceFillLayerId,
        MapFlightLayers.airspaceLineLayerId,
        MapFlightLayers.tailSourceId,
        MapFlightLayers.windowSourceId,
        MapFlightLayers.headSourceId,
        MapFlightLayers.pilotSourceId,
      ]);
      expect(style.images, contains(MapFlightLayers.pilotImageId));
      // Mock airspace polygon is static geography.
      final poly = _features(
        style.sourceData[MapFlightLayers.airspaceSourceId]!,
      );
      expect(poly.single['geometry']['type'], 'Polygon');
    });

    test(
      're-attaching to a reloaded style re-adds layers with current data',
      () async {
        layers.updateTrack(_flight(10));
        await layers.attach(style);
        final reloaded = RecordingStyleController();
        layers.detach();
        await layers.attach(reloaded);
        expect(reloaded.layerIds, contains(MapFlightLayers.windowSourceId));
        expect(
          _vertexCount(reloaded.sourceData[MapFlightLayers.windowSourceId]!),
          greaterThan(1),
        );
      },
    );

    test('history window and older tail on/off', () async {
      final pts = [
        for (var m = 0; m <= 30; m++)
          FlightPoint(
            timestamp: _t0.add(Duration(minutes: m)),
            latitude: 47.5,
            longitude: 13.6 + m * 0.001,
            altitude: 1500,
            vario: 2,
          ),
      ];
      layers.configure(
        showTrack: true,
        historyMinutes: 10,
        showOlderTail: true,
        showAirspace: true,
      );
      layers.updateTrack(pts);
      await layers.attach(style);
      // Window: last 10 minutes = points 20..30 (11 vertices).
      expect(
        _vertexCount(style.sourceData[MapFlightLayers.windowSourceId]!),
        11,
      );
      // Tail: points 0..20 joined to the window start.
      expect(_vertexCount(style.sourceData[MapFlightLayers.tailSourceId]!), 21);

      layers.configure(
        showTrack: true,
        historyMinutes: 10,
        showOlderTail: false,
        showAirspace: true,
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        _features(style.sourceData[MapFlightLayers.tailSourceId]!),
        isEmpty,
      );
      expect(
        _vertexCount(style.sourceData[MapFlightLayers.windowSourceId]!),
        11,
      );
    });

    test('track hidden sends empty track sources', () async {
      layers.updateTrack(_flight(10));
      await layers.attach(style);
      layers.configure(
        showTrack: false,
        historyMinutes: 10,
        showOlderTail: true,
        showAirspace: false,
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        _features(style.sourceData[MapFlightLayers.windowSourceId]!),
        isEmpty,
      );
      expect(
        _features(style.sourceData[MapFlightLayers.airspaceSourceId]!),
        isEmpty,
      );
    });

    test(
      '3 h flight: a new fix only sends head data; full rebuilds throttled',
      () async {
        final all = _flight(10800 + 60);
        final live = all.sublist(0, 10800); // growing live list (same identity)
        layers.configure(
          showTrack: true,
          historyMinutes: 0,
          showOlderTail: true,
          showAirspace: true,
        );
        layers.updateTrack(live);
        await layers.attach(style);
        final rebuildsBefore = layers.fullRebuilds;
        style.updates.clear();

        for (var i = 0; i < 9; i++) {
          live.add(all[10800 + i]);
          now = now.add(const Duration(seconds: 1));
          layers.updateTrack(live);
          await Future<void>.delayed(Duration.zero);
        }
        expect(layers.fullRebuilds, rebuildsBefore, reason: '< 10 s elapsed');
        expect(style.updatesFor(MapFlightLayers.windowSourceId), 0);
        expect(style.updatesFor(MapFlightLayers.headSourceId), 9);
        // Head only carries the recent points, not the whole flight.
        expect(_vertexCount(style.updates.last.$2), 10);

        // Full-flight window: its start never moves, so the long window is
        // not re-sent periodically - only the head keeps growing.
        live.add(all[10809]);
        now = now.add(const Duration(seconds: 1));
        layers.updateTrack(live);
        await Future<void>.delayed(Duration.zero);
        expect(layers.fullRebuilds, rebuildsBefore);
        expect(_vertexCount(style.updates.last.$2), 11);
      },
    );

    test('a moving history window is rebuilt every 10 s', () async {
      final all = _flight(400);
      final live = all.sublist(0, 200);
      layers.configure(
        showTrack: true,
        historyMinutes: 1,
        showOlderTail: true,
        showAirspace: true,
      );
      layers.updateTrack(live);
      await layers.attach(style);
      final before = layers.fullRebuilds;
      for (var i = 0; i < 9; i++) {
        live.add(all[200 + i]);
        now = now.add(const Duration(seconds: 1));
        layers.updateTrack(live);
      }
      expect(layers.fullRebuilds, before);
      live.add(all[209]);
      now = now.add(const Duration(seconds: 1));
      layers.updateTrack(live);
      await Future<void>.delayed(Duration.zero);
      expect(layers.fullRebuilds, before + 1);
      expect(
        _features(style.sourceData[MapFlightLayers.headSourceId]!),
        isEmpty,
      );
      // 1 min window at 1 Hz = 61 vertices; the rest went to the tail.
      expect(
        _vertexCount(style.sourceData[MapFlightLayers.windowSourceId]!),
        61,
      );
      expect(
        _vertexCount(style.sourceData[MapFlightLayers.tailSourceId]!),
        150,
      );
    });

    test('head exceeding the threshold forces a rebuild', () async {
      final all = _flight(400);
      final live = all.sublist(0, 10);
      layers.updateTrack(live);
      await layers.attach(style);
      final before = layers.fullRebuilds;
      live.addAll(all.sublist(10, 140)); // 130 new points at once
      layers.updateTrack(live);
      expect(layers.fullRebuilds, before + 1);
    });

    test(
      'replaced track (seek / new flight) triggers a full rebuild',
      () async {
        layers.updateTrack(_flight(50));
        await layers.attach(style);
        final before = layers.fullRebuilds;
        layers.updateTrack(_flight(20)); // shorter: seek back
        expect(layers.fullRebuilds, before + 1);
      },
    );

    test('pilot symbol is only shown while visible and deduped', () async {
      await layers.attach(style);
      style.updates.clear();
      layers.updatePilot(const LatLng(47.5, 13.6), 90, visible: false);
      expect(
        style.updatesFor(MapFlightLayers.pilotSourceId),
        0,
        reason: 'already empty',
      );
      layers.updatePilot(const LatLng(47.5, 13.6), 90, visible: true);
      layers.updatePilot(const LatLng(47.5, 13.6), 90, visible: true);
      expect(style.updatesFor(MapFlightLayers.pilotSourceId), 1);
      final f = _features(style.sourceData[MapFlightLayers.pilotSourceId]!);
      expect(f.single['properties']['r'], 90.0);
      layers.updatePilot(const LatLng(47.5, 13.6), 90, visible: false);
      expect(
        _features(style.sourceData[MapFlightLayers.pilotSourceId]!),
        isEmpty,
      );
    });

    test('update failures keep running and retry with current data', () async {
      final live = _flight(20);
      layers.updateTrack(live);
      await layers.attach(style);
      style.failUpdates = true;
      live.add(_flight(21).last);
      layers.updateTrack(live); // fails asynchronously
      await Future<void>.delayed(Duration.zero);
      final before = layers.fullRebuilds;
      style.failUpdates = false;
      live.add(_flight(22).last);
      layers.updateTrack(live);
      await Future<void>.delayed(Duration.zero);
      expect(layers.fullRebuilds, before + 1, reason: 'dirty -> full retry');
      expect(
        _vertexCount(style.sourceData[MapFlightLayers.windowSourceId]!),
        22,
      );
    });

    test('updates before attach are applied on attach', () async {
      layers.updateTrack(_flight(30));
      expect(style.updates, isEmpty);
      await layers.attach(style);
      expect(
        _vertexCount(style.sourceData[MapFlightLayers.windowSourceId]!),
        30,
      );
    });
  });
}
