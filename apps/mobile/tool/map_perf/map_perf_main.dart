// On-device smoothness and frame-budget harness for the flight map (OpenSpec
// change smooth-map-camera-and-native-track, tasks 6.2 / 6.3).
//
// A standalone app entry point (not part of the shipped app) so the real
// MapLibre platform view, style loading and native layers are exercised with
// the normal binding. It replays the bundled Krippenstein-Aussee IGC played
// forward/backward/forward (~3 h, ~10.5k fixes at 1 Hz) through the real
// replay -> telemetry repository -> MapWidget pipeline:
//
//   cd apps/mobile
//   flutter run --profile -t tool/map_perf/map_perf_main.dart -d <device>
//
// Results are printed as one `MAP_PERF_RESULTS {json}` log line. Lines
// starting with `MAP_PERF_MARKER` / `MAP_PERF_START` let a host script take
// screenshots or screen recordings at the right moments.
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:brandyfly/data/repositories/telemetry_repository.dart';
import 'package:brandyfly/domain/map_motion/motion_smoother.dart';
import 'package:brandyfly/domain/models/ui_config.dart';
import 'package:brandyfly/models/flight_model.dart';
import 'package:brandyfly/models/lat_lng.dart';
import 'package:brandyfly/services/flight_replay_service.dart';
import 'package:brandyfly/services/flight_storage_service.dart';
import 'package:brandyfly/services/igc_parser_service.dart';
import 'package:brandyfly/services/maplibre_map_service.dart';
import 'package:brandyfly/ui/features/map/views/map_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:maplibre/maplibre.dart' show Geographic;

/// Records every camera write with its frame timestamp.
class _RecordingMapService extends MapLibreMapService {
  final List<(Duration, LatLng, double)> writes = [];

  @override
  Future<void> moveCamera({
    required LatLng position,
    double? zoom,
    double? bearing,
    double? pitch,
    EdgeInsets padding = EdgeInsets.zero,
  }) {
    writes.add((
      SchedulerBinding.instance.currentFrameTimeStamp,
      position,
      bearing ?? 0,
    ));
    return super.moveCamera(
      position: position,
      zoom: zoom,
      bearing: bearing,
      pitch: pitch,
      padding: padding,
    );
  }
}

/// Forward, backward, forward: a continuous ~3 h path from one real flight.
FlightModel _longFlight(FlightModel base) {
  final src = base.points;
  final out = <FlightPoint>[];
  var t = src.first.timestamp;
  void add(FlightPoint p, {bool reverse = false}) {
    t = t.add(const Duration(seconds: 1));
    out.add(
      FlightPoint(
        timestamp: t,
        latitude: p.latitude,
        longitude: p.longitude,
        altitude: p.altitude,
        vario: reverse ? -p.vario : p.vario,
        speed: p.speed,
        heading: reverse ? (p.heading + 180) % 360 : p.heading,
      ),
    );
  }

  for (final p in src) {
    add(p);
  }
  for (final p in src.reversed) {
    add(p, reverse: true);
  }
  for (final p in src) {
    add(p);
  }
  return FlightModel(
    id: 'perf_long',
    title: 'Perf ping-pong',
    date: out.first.timestamp,
    points: out,
  );
}

double _r(double v, [int d = 3]) => double.parse(v.toStringAsFixed(d));

/// Camera smoothness of recorded writes from index [from] to the end.
Map<String, Object> _smoothness(
  List<(Duration, LatLng, double)> writes,
  int from,
) {
  final w = writes.sublist(from);
  if (w.length < 3) return {'cameraWrites': w.length};
  final steps = <double>[];
  final rot = <double>[];
  for (var i = 1; i < w.length; i++) {
    steps.add(
      MotionSmoother.distanceM(
        w[i - 1].$2.latitude,
        w[i - 1].$2.longitude,
        w[i].$2.latitude,
        w[i].$2.longitude,
      ),
    );
    rot.add(MotionSmoother.shortestDelta(w[i - 1].$3, w[i].$3).abs());
  }
  final span = (w.last.$1 - w.first.$1).inMicroseconds / 1e6;
  final s = [...steps]..sort();
  final r = [...rot]..sort();
  final median = s[s.length ~/ 2];
  return {
    'cameraWrites': w.length,
    'writesPerS': _r(w.length / span, 1),
    'medianStepM': _r(median),
    'p99StepM': _r(s[(s.length * 0.99).floor().clamp(0, s.length - 1)]),
    'maxStepM': _r(s.last),
    // One big move per fix (stepping) shows as max >> median.
    'maxOverMedianStep': median == 0 ? 0 : _r(s.last / median, 2),
    'medianRotationDeg': _r(r[r.length ~/ 2]),
    'maxRotationDeg': _r(r.last),
  };
}

Map<String, Object> _frameSummary(List<FrameTiming> timings) {
  double ms(Duration d) => d.inMicroseconds / 1000;
  Map<String, Object> stats(List<double> v) {
    if (v.isEmpty) return {};
    v.sort();
    double pct(double p) => v[math.min(v.length - 1, (v.length * p).floor())];
    return {
      'avgMs': _r(v.reduce((a, b) => a + b) / v.length, 2),
      'p90Ms': _r(pct(0.9), 2),
      'p99Ms': _r(pct(0.99), 2),
      'maxMs': _r(v.last, 2),
      'over16ms': v.where((x) => x > 16.0).length,
    };
  }

  return {
    'frames': timings.length,
    'build': stats([for (final t in timings) ms(t.buildDuration)]),
    'raster': stats([for (final t in timings) ms(t.rasterDuration)]),
  };
}

void _log(String line) => debugPrint(line, wrapWidth: 100000);

Future<void> _wait(Duration d) => Future<void>.delayed(d);

typedef _Scenario =
    Future<void> Function(
      String key, {
      required int speed,
      required MapOrientation mode,
      required int historyMinutes,
      int? seekTo,
      Duration length,
    });

Future<void> _shortScenarios(
  _Scenario scenario,
  Future<void> Function(String) marker,
) async {
  await scenario(
    'replay_1x_trackup',
    speed: 1,
    mode: MapOrientation.trackUp,
    historyMinutes: 10,
  );
  await marker('trackup_1x');
  await scenario(
    'replay_1x_northup',
    speed: 1,
    mode: MapOrientation.northUp,
    historyMinutes: 10,
  );
  await scenario(
    'replay_4x_northup',
    speed: 4,
    mode: MapOrientation.northUp,
    historyMinutes: 10,
  );
  await marker('northup_4x');
  await scenario(
    'replay_4x_trackup',
    speed: 4,
    mode: MapOrientation.trackUp,
    historyMinutes: 10,
  );
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _PerfApp());
}

class _PerfApp extends StatefulWidget {
  const _PerfApp();

  @override
  State<_PerfApp> createState() => _PerfAppState();
}

class _PerfAppState extends State<_PerfApp> {
  final _service = _RecordingMapService();
  final _mapKey = GlobalKey<MapWidgetState>();
  FlightReplayService? _replay;
  TelemetryRepository? _repo;
  MapOrientation _orientation = MapOrientation.trackUp;
  int _history = 10;

  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  Future<void> _run() async {
    final igc = await rootBundle.loadString(
      FlightStorageService.sampleFlightAssetPath,
    );
    final flight = _longFlight(const IGCParserService().parseIgc(igc));
    final replay = FlightReplayService(flight: flight);
    final repo = TelemetryRepository(replayService: replay);
    repo.setReplayActive(true);
    replay.seekTo(300);
    setState(() {
      _replay = replay;
      _repo = repo;
    });
    final results = <String, Object>{
      'flightPoints': flight.points.length,
      'flightDurationMin': flight.points.last.timestamp
          .difference(flight.points.first.timestamp)
          .inMinutes,
    };
    // Style and tiles.
    await _wait(const Duration(seconds: 8));
    results['layersAttached'] =
        _mapKey.currentState?.flightLayers.isAttached ?? false;

    Future<void> scenario(
      String key, {
      required int speed,
      required MapOrientation mode,
      required int historyMinutes,
      int? seekTo,
      Duration length = const Duration(seconds: 12),
    }) async {
      replay.pause();
      if (seekTo != null) replay.seekTo(seekTo);
      setState(() {
        _orientation = mode;
        _history = historyMinutes;
      });
      replay.setSpeedMultiplier(speed);
      await _wait(const Duration(seconds: 2));
      final layers = _mapKey.currentState!.flightLayers..resetDiagnostics();
      final timings = <FrameTiming>[];
      void collect(List<FrameTiming> t) => timings.addAll(t);
      SchedulerBinding.instance.addTimingsCallback(collect);
      final from = _service.writes.length;
      _log('MAP_PERF_START $key');
      replay.play();
      await _wait(length);
      replay.pause();
      await _wait(const Duration(milliseconds: 300));
      SchedulerBinding.instance.removeTimingsCallback(collect);
      results['${key}_frames'] = _frameSummary(timings);
      results['${key}_camera'] = _smoothness(_service.writes, from);
      // Steady state: skip the first second after (re)starting playback.
      final settle = _service.writes.indexWhere(
        (w) => w.$1 - _service.writes[from].$1 > const Duration(seconds: 1),
        from,
      );
      if (settle > 0) {
        results['${key}_cameraSteady'] = _smoothness(_service.writes, settle);
      }
      results['${key}_trackLayers'] = {
        'trackPoints': replay.currentIndex + 1,
        'attached': layers.isAttached,
        'fullRebuilds': layers.fullRebuilds,
        'headUpdates': layers.headUpdates,
        'maxFullBuildMs': layers.maxFullBuildMicros / 1000,
        'maxHeadBuildMs': layers.maxHeadBuildMicros / 1000,
        'maxNativeSendMs': layers.maxSendMicros / 1000,
      };
    }

    Future<void> marker(String name) async {
      // Where does the native map draw the displayed pilot vs. where the
      // screen marker is anchored?
      final state = _mapKey.currentState!;
      final frame = state.motionFrame;
      final controller = _service.controller;
      final box = state.context.findRenderObject() as RenderBox?;
      if (frame != null && controller != null && box != null) {
        final native = controller.toScreenLocation(
          Geographic(lon: frame.pilot.longitude, lat: frame.pilot.latitude),
        );
        final size = box.size;
        final anchor = Offset(
          size.width / 2,
          size.height * (1 + frame.topPaddingFraction) / 2,
        );
        results['${name}_anchorCheck'] = {
          'viewport': [_r(size.width, 1), _r(size.height, 1)],
          'nativePilotPx': [_r(native.dx, 1), _r(native.dy, 1)],
          'markerAnchorPx': [_r(anchor.dx, 1), _r(anchor.dy, 1)],
          'topPaddingFraction': frame.topPaddingFraction,
          'following': frame.following,
        };
      }
      _log('MAP_PERF_MARKER $name');
      await _wait(const Duration(seconds: 4));
    }

    // 6.2: 1x and 4x replay in both orientations.
    const onlyLong = bool.fromEnvironment('MAP_PERF_ONLY_LONG');
    if (!onlyLong) await _shortScenarios(scenario, marker);
    // 6.3: >= 2 h of recorded track, full-flight window (largest rebuilds).
    await scenario(
      'long_track_1x_full_window',
      speed: 1,
      mode: MapOrientation.trackUp,
      historyMinutes: 0,
      seekTo: 9000,
      length: const Duration(seconds: 25),
    );
    await marker('long_track');
    await scenario(
      'long_track_4x_full_window',
      speed: 4,
      mode: MapOrientation.northUp,
      historyMinutes: 0,
      length: const Duration(seconds: 40),
    );

    // Pilot icon size: release center-lock so the native symbol shows.
    _mapKey.currentState!.camera.beginManualPan();
    await marker('panned_native_symbol');
    _mapKey.currentState!.camera.recenter();
    await marker('recentered_flutter_marker');

    // One line per entry: logcat truncates long lines.
    for (final e in results.entries) {
      _log('MAP_PERF_RESULT ${e.key} ${jsonEncode(e.value)}');
    }
    _log('MAP_PERF_DONE');
  }

  @override
  Widget build(BuildContext context) {
    final repo = _repo;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: repo == null || _replay == null
            ? const SizedBox.expand()
            : MapWidget(
                key: _mapKey,
                mapService: _service,
                telemetry: repo.telemetry,
                orientation: _orientation,
                mapTrackHistoryMinutes: _history,
                showThermals: false,
              ),
      ),
    );
  }
}
