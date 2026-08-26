import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'adapters/maplibre_adapter.dart';
import 'adapters/maplibre_gl_adapter.dart';
import 'benchmark_scenario.dart';
import 'fixture_loader.dart';
import 'measurement_harness.dart';
import 'result_schema.dart';

/// Select the active adapter at compile time.
/// Build with --dart-define=BENCHMARK_ADAPTER=maplibre or maplibre_gl.
const String _adapterKey = String.fromEnvironment(
  'BENCHMARK_ADAPTER',
  defaultValue: 'maplibre',
);

void main() {
  runApp(const BenchmarkApp());
}

class BenchmarkApp extends StatelessWidget {
  const BenchmarkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BrandyFly Map Benchmark',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const BenchmarkHomePage(),
    );
  }
}

class BenchmarkHomePage extends StatefulWidget {
  const BenchmarkHomePage({super.key});

  @override
  State<BenchmarkHomePage> createState() => _BenchmarkHomePageState();
}

class _BenchmarkHomePageState extends State<BenchmarkHomePage> {
  BenchmarkResult? _result;
  bool _running = false;

  MapEngineAdapter _buildAdapter() {
    switch (_adapterKey) {
      case 'maplibre_gl':
        return MaplibreGlAdapter();
      case 'maplibre':
      default:
        return MaplibreAdapter();
    }
  }

  void _startBenchmark() {
    setState(() {
      _running = true;
      _result = null;
    });
  }

  Future<void> _onScenarioComplete(
    MeasurementSnapshot snapshot,
    BenchmarkFixtures fixtures,
  ) async {
    final adapter = _buildAdapter();
    final result = BenchmarkResult(
      device: DeviceInfo(
        model: 'FILL_IN_DEVICE_MODEL',
        os: Platform.operatingSystem,
        osVersion: Platform.operatingSystemVersion,
        buildMode: 'release',
      ),
      package: PackageInfo(
        name: adapter.adapterName,
        version: adapter.packageVersion,
      ),
      startup: snapshot.startup,
      frames: snapshot.frameMetrics,
      memory: snapshot.memory,
      thermal: const ThermalInfo(invalidated: false),
      heartbeat: snapshot.heartbeat,
      fixtureVersion: fixtures.fixtureVersion,
      fixtureChecksum: fixtures.manifest['fixtures'] != null
          ? ((fixtures.manifest['fixtures'] as List<dynamic>).firstWhere(
                (f) => (f as Map<String, dynamic>)['id'] == 'alpine_overview',
                orElse: () => <String, dynamic>{'sha256': 'N/A'},
              ) as Map<String, dynamic>)['sha256'] as String? ??
              'N/A'
          : 'N/A',
      runTimestamp: DateTime.now().toIso8601String(),
    );

    setState(() {
      _result = result;
      _running = false;
    });

    await _saveResult(result);
  }

  Future<void> _saveResult(BenchmarkResult result) async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File(
        '${dir.path}/benchmark_result_${_adapterKey}_${DateTime.now().millisecondsSinceEpoch}.json',
      );
      await file.writeAsString(result.toJsonString());
      debugPrint('[benchmark] Result saved to: ${file.path}');
    } catch (e) {
      debugPrint('[benchmark] Failed to save result: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_running) {
      return Scaffold(
        body: BenchmarkScenarioWidget(
          adapter: _buildAdapter(),
          onComplete: _onScenarioComplete,
        ),
      );
    }

    if (_result != null) {
      return _buildResultScreen(_result!);
    }

    return _buildStartScreen();
  }

  Widget _buildStartScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map, color: Colors.cyanAccent, size: 64),
            const SizedBox(height: 24),
            const Text(
              'BrandyFly\nMap Engine Benchmark',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Adapter: $_adapterKey',
              style: const TextStyle(color: Colors.cyanAccent, fontSize: 14),
            ),
            const SizedBox(height: 32),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                '⚠ Before starting a valid benchmark run:\n'
                '• Place alpine_overview.pmtiles and alpine_terrain.pmtiles\n'
                '  in the app support directory.\n'
                '• Enable airplane mode (network isolation).\n'
                '• Allow the device to thermally stabilise for 5 minutes.\n'
                '• Follow all steps in BENCHMARK_PROCEDURE.md.',
                style: TextStyle(color: Colors.amber, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _startBenchmark,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Benchmark'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultScreen(BenchmarkResult result) {
    final passed = result.frames.passesFpsGate && !result.thermal.invalidated;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Benchmark Result'),
        actions: [
          TextButton(
            onPressed: () => setState(() {
              _result = null;
              _running = false;
            }),
            child: const Text('Run Again', style: TextStyle(color: Colors.cyanAccent)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pass/fail badge
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: passed ? Colors.green.shade900 : Colors.red.shade900,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                passed
                    ? '✓ PASSED — All mandatory gates met'
                    : '✗ FAILED — One or more mandatory gates not met',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            _resultRow('Adapter', result.package.name),
            _resultRow('Version', result.package.version),
            _resultRow('First map (ms)', '${result.startup.firstMapMs}'),
            _resultRow(
              'p50 frame (ms)',
              result.frames.p50Ms.toStringAsFixed(1),
            ),
            _resultRow(
              'p95 frame (ms) [gate ≤16.7]',
              result.frames.p95Ms.toStringAsFixed(1),
              failing: result.frames.p95Ms > 16.7,
            ),
            _resultRow(
              'p99 frame (ms)',
              result.frames.p99Ms.toStringAsFixed(1),
            ),
            _resultRow('Frames > 16.7ms', '${result.frames.over16Count}'),
            _resultRow(
              'Stalls > 100ms',
              '${result.frames.stallsOver100Count}',
            ),
            _resultRow(
              'Peak memory (MB)',
              result.memory.peakMb.toStringAsFixed(1),
            ),
            _resultRow(
              'Thermal invalidated',
              result.thermal.invalidated ? 'YES — run excluded' : 'No',
              failing: result.thermal.invalidated,
            ),
            _resultRow(
              'Max sensor delay (ms)',
              '${result.heartbeat.maxSensorDelayMs}',
            ),
            const Divider(color: Colors.white24, height: 32),
            const Text(
              'Raw JSON (saved to app support directory):',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text(
              result.toJsonString(),
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultRow(String label, String value, {bool failing = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              color: failing ? Colors.redAccent : Colors.cyanAccent,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
