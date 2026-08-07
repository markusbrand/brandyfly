import 'dart:async';

import 'package:brandyfly_native/brandyfly_native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  final config = MockFlightModeConfig.fromEnvironment();
  config.validateBuildMode(isReleaseBuild: kReleaseMode);
  runApp(BrandyFlyApp(config: config));
}

class BrandyFlyApp extends StatefulWidget {
  const BrandyFlyApp({
    super.key,
    required this.config,
    this.native = const BrandyflyNative(),
  });

  final MockFlightModeConfig config;
  final BrandyflyNative native;

  @override
  State<BrandyFlyApp> createState() => _BrandyFlyAppState();
}

class _BrandyFlyAppState extends State<BrandyFlyApp> {
  MockFlightReplay? _replay;
  Timer? _timer;
  String? _platformVersion;
  String? _startupError;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      if (widget.config.enabled) {
        await widget.native.configureLocalMockFlightMode(widget.config);
        _replay = MockFlightReplay(widget.config);
        _timer = Timer.periodic(const Duration(seconds: 2), (_) {
          if (!mounted || _replay == null) {
            return;
          }
          setState(() {
            _replay!.advance();
          });
        });
      } else {
        _platformVersion = await widget.native.getPlatformVersion() ??
            'Unknown platform version';
      }
    } on PlatformException catch (error) {
      _startupError = error.message ?? error.code;
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BrandyFly',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      home: _startupError != null
          ? _StartupErrorView(message: _startupError!)
          : _loading
              ? const _LoadingView()
              : widget.config.enabled
                  ? _MockFlightView(
                      config: widget.config,
                      replay: _replay!,
                      onNext: () => setState(() {
                        _replay!.advance();
                      }),
                      onReset: () => setState(() {
                        _replay!.reset();
                      }),
                    )
                  : _LiveFlightView(platformVersion: _platformVersion ?? 'Unknown'),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _StartupErrorView extends StatelessWidget {
  const _StartupErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BrandyFly')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _LiveFlightView extends StatelessWidget {
  const _LiveFlightView({required this.platformVersion});

  final String platformVersion;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BrandyFly'),
        actions: const [_ModeChip(label: 'LIVE', color: Colors.green)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _SectionCard(
            title: 'Native platform',
            child: Text('Running on: $platformVersion'),
          ),
          const SizedBox(height: 16),
          const _SectionCard(
            title: 'Mock flight mode',
            child: Text(
              'Disabled. Use BRANDYFLY_LOCAL_MOCK_FLIGHT_MODE=true for deterministic local testing.',
            ),
          ),
        ],
      ),
    );
  }
}

class _MockFlightView extends StatelessWidget {
  const _MockFlightView({
    required this.config,
    required this.replay,
    required this.onNext,
    required this.onReset,
  });

  final MockFlightModeConfig config;
  final MockFlightReplay replay;
  final VoidCallback onNext;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final frame = replay.currentFrame;
    return Scaffold(
      appBar: AppBar(
        title: const Text('BrandyFly'),
        actions: const [_ModeChip(label: 'SIMULATED', color: Colors.orange)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _SectionCard(
            title: 'Mock flight session',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Fixture: ${config.fixtureVersion}'),
                Text('Seed: ${config.seed}'),
                Text('Clock step: ${config.logicalClockStep.inMilliseconds} ms'),
                Text('Provenance: ${config.provenance}'),
                Text('Session label: ${config.sessionLabel}'),
                Text('Replay hash: ${replay.canonicalReplayHash}'),
                Text('Marker: ${frame.sessionMarker}'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ElevatedButton(
                onPressed: onNext,
                child: const Text('Advance scenario'),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: onReset,
                child: const Text('Reset replay'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: frame.title,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FeatureLine(label: 'Telemetry', value: frame.telemetrySummary),
                _FeatureLine(label: 'Map', value: frame.mapSummary),
                _FeatureLine(label: 'Logs', value: frame.logSummary),
                _FeatureLine(label: 'Alerts', value: frame.alertSummary),
                _FeatureLine(label: 'Upload', value: frame.uploadSummary),
                _FeatureLine(label: 'Export', value: frame.exportSummary),
                _FeatureLine(
                  label: 'State',
                  value: frame.degraded
                      ? (frame.stale ? 'Stale and degraded' : 'Degraded')
                      : 'Healthy',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Simulation details',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Scenario kind: ${frame.scenarioName}'),
                Text('Occurred at: ${frame.occurredAt.toUtc()}'),
                Text('Canonical event hash: ${frame.canonicalEventHash}'),
                Text('Mode is explicit and local-only: ${config.enabled}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Chip(
        label: Text(label),
        side: BorderSide(color: color),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _FeatureLine extends StatelessWidget {
  const _FeatureLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text('$label: $value'),
    );
  }
}
