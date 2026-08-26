import 'package:flutter/material.dart';

import '../benchmark_scenario.dart';
import '../measurement_harness.dart';

/// Benchmark adapter stub for `maplibre_gl` when Candidate 1 (`maplibre`) is built.
class MaplibreGlAdapter implements MapEngineAdapter {
  @override
  String get adapterName => 'maplibre_gl 0.27.0 (disabled)';

  @override
  String get packageVersion => '0.27.0';

  @override
  Future<void> loadOverlays(Map<String, dynamic> overlaysJson) async {}

  @override
  Future<void> executeWaypoint(Map<String, dynamic> waypoint) async {}

  @override
  Widget buildMapWidget(MeasurementHarness harness) {
    return const Center(
      child: Text('maplibre_gl not enabled in this build'),
    );
  }
}

