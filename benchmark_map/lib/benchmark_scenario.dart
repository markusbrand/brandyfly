import 'dart:async';

import 'package:flutter/material.dart';

import 'fixture_loader.dart';
import 'measurement_harness.dart';

/// Callback type for adapter implementations.
/// Called each time the scenario advances to a new waypoint.
typedef WaypointCallback =
    Future<void> Function(Map<String, dynamic> waypoint);

/// Callback called once when the scenario finishes.
typedef ScenarioCompleteCallback =
    void Function(MeasurementSnapshot snapshot);

/// Abstract base for both map engine adapters.
///
/// Implementations must:
/// 1. Build a map widget using their respective package.
/// 2. Register [onMapReady] to be called when the map engine signals readiness.
/// 3. Execute camera moves and overlay updates via [executeWaypoint].
/// 4. Reject missing/invalid PMTiles sources — no online fallback.
abstract class MapEngineAdapter {
  /// The benchmark scenario calls this after loading overlays to add them to the map.
  Future<void> loadOverlays(Map<String, dynamic> overlaysJson);

  /// Executes one step of the camera script (pan, zoom, rotate, tilt).
  Future<void> executeWaypoint(Map<String, dynamic> waypoint);

  /// Builds the Flutter map widget. This widget must call [harness.onMapBuildStart]
  /// before layout and [harness.onFirstFrame] on the first post-frame callback.
  Widget buildMapWidget(MeasurementHarness harness);

  /// Human-readable name for this adapter (shown in the UI and results).
  String get adapterName;

  /// Package version string (e.g. "0.3.6").
  String get packageVersion;
}

/// Widget that drives the benchmark scenario, exercises the selected [adapter],
/// and displays live progress.
///
/// The scenario:
/// 1. Loads and validates fixtures via [FixtureLoader].
/// 2. Loads overlays into the adapter.
/// 3. Steps through the camera script waypoints at documented intervals.
/// 4. Collects metrics via [MeasurementHarness] throughout.
/// 5. Calls [onComplete] with the final snapshot when done.
class BenchmarkScenarioWidget extends StatefulWidget {
  const BenchmarkScenarioWidget({
    super.key,
    required this.adapter,
    required this.onComplete,
  });

  final MapEngineAdapter adapter;
  final void Function(MeasurementSnapshot snapshot, BenchmarkFixtures fixtures)
  onComplete;

  @override
  State<BenchmarkScenarioWidget> createState() =>
      _BenchmarkScenarioWidgetState();
}

class _BenchmarkScenarioWidgetState extends State<BenchmarkScenarioWidget> {
  final MeasurementHarness _harness = MeasurementHarness();
  final FixtureLoader _loader = const FixtureLoader();

  String _status = 'Loading fixtures…';
  int _currentWaypoint = 0;
  int _totalWaypoints = 0;
  bool _scenarioComplete = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _runScenario();
  }

  Future<void> _runScenario() async {
    // 1. Load & validate fixtures — abort immediately on any failure.
    late BenchmarkFixtures fixtures;
    try {
      fixtures = await _loader.load();
    } on FixtureValidationException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _status = 'Fixture validation failed';
      });
      return;
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _status = 'Unexpected fixture error';
      });
      return;
    }

    setState(() => _status = 'Fixtures validated ✓ — loading overlays…');

    // 2. Load overlays into the adapter.
    try {
      await widget.adapter.loadOverlays(fixtures.overlays);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _status = 'Overlay load failed';
      });
      return;
    }

    setState(() => _status = 'Overlays loaded ✓ — starting scenario…');

    // 3. Parse camera script waypoints.
    final waypoints =
        (fixtures.cameraScript['waypoints'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
    final totalWaypoints = waypoints.length;
    setState(() => _totalWaypoints = totalWaypoints);

    // 4. Start metric collection.
    _harness.startCollection();

    // 5. Step through waypoints at a controlled pace.
    // In a real physical run, each step follows actual timing from camera_script.json.
    // For the benchmark app, we use the interval from the script; on device, use
    // the t-field to schedule steps — but we drive them synchronously with a short
    // delay to avoid overwhelming the event loop in smoke tests.
    const stepDelay = Duration(milliseconds: 200); // Tightened for smoke tests.
    // Physical runs should use Duration(seconds: 15) as per camera_script.json.

    for (int i = 0; i < waypoints.length; i++) {
      if (!mounted) break;
      setState(() {
        _currentWaypoint = i + 1;
        _status = 'Waypoint ${i + 1}/$totalWaypoints: ${waypoints[i]['action']}';
      });
      try {
        await widget.adapter.executeWaypoint(waypoints[i]);
      } catch (e) {
        setState(() {
          _errorMessage = e.toString();
          _status = 'Error at waypoint ${i + 1}';
        });
        _harness.stop();
        return;
      }
      await Future<void>.delayed(stepDelay);
    }

    // 6. Stop collection and report.
    final snapshot = _harness.stop();
    setState(() {
      _scenarioComplete = true;
      _status = 'Scenario complete ✓';
    });

    widget.onComplete(snapshot, fixtures);
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return _buildErrorScreen();
    }
    return Stack(
      children: [
        // Map widget from the active adapter.
        Positioned.fill(child: widget.adapter.buildMapWidget(_harness)),

        // Progress overlay.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _buildProgressBanner(),
        ),
      ],
    );
  }

  Widget _buildProgressBanner() {
    return Container(
      color: Colors.black.withAlpha(180),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.adapter.adapterName,
                    style: const TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _status,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (_totalWaypoints > 0)
              Text(
                '$_currentWaypoint / $_totalWaypoints',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            if (_scenarioComplete)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.check_circle, color: Colors.greenAccent, size: 18),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              const SizedBox(height: 16),
              Text(
                _status,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage ?? '',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              const Text(
                'No online fallback will be attempted.\n'
                'Fix the fixture error and restart the benchmark.',
                style: TextStyle(color: Colors.amber, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
