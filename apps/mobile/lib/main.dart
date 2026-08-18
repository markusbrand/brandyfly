import 'dart:async';

import 'package:brandyfly_native/brandyfly_native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/screen_manager_service.dart';
import 'services/ui_persistence_service.dart';
import 'widgets/layout/layout_strategy_container.dart';
import 'widgets/navigation/top_nav_bar.dart';
import 'widgets/settings/ui_settings_panel.dart';

void main() {
  final config = MockFlightModeConfig.fromEnvironment();
  final effectiveConfig = config.copyWith(
    enabled: kDebugMode || config.enabled,
  );
  effectiveConfig.validateBuildMode(isReleaseBuild: kReleaseMode);
  runApp(BrandyFlyApp(config: effectiveConfig));
}

class BrandyFlyApp extends StatefulWidget {
  const BrandyFlyApp({
    super.key,
    required this.config,
    this.native = const BrandyflyNative(),
    this.screenManager,
  });

  final MockFlightModeConfig config;
  final BrandyflyNative native;
  final ScreenManagerService? screenManager;

  @override
  State<BrandyFlyApp> createState() => _BrandyFlyAppState();
}

class _BrandyFlyAppState extends State<BrandyFlyApp> {
  MockFlightReplay? _replay;
  Timer? _timer;
  String? _platformVersion;
  String? _startupError;
  bool _loading = true;
  late ScreenManagerService _screenManager;

  @override
  void initState() {
    super.initState();
    _screenManager = widget.screenManager ?? ScreenManagerService();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      if (widget.screenManager == null) {
        final persistence = await UIPersistenceService.init();
        final loadedConfig = persistence.loadConfig();
        _screenManager = ScreenManagerService(
          initialConfig: loadedConfig,
          persistenceService: persistence,
        );
      }

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
        _platformVersion =
            await widget.native.getPlatformVersion() ??
            'Unknown platform version';
      }
    } on PlatformException catch (error) {
      _startupError = error.message ?? error.code;
    } catch (error) {
      _startupError = error.toString();
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = false;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _screenManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _screenManager,
      builder: (context, _) {
        return MaterialApp(
          title: 'BrandyFly',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
            ),
          ),
          themeMode: ThemeMode.dark,
          home: _startupError != null
              ? _StartupErrorView(message: _startupError!)
              : _loading
              ? const _LoadingView()
              : TopNavBarOverlay(
                  screenManager: _screenManager,
                  child: _screenManager.isSettingsVisible
                      ? UISettingsPanel(screenManager: _screenManager)
                      : widget.config.enabled
                      ? _MockFlightView(
                          config: widget.config,
                          replay: _replay!,
                          screenManager: _screenManager,
                          onNext: () => setState(() {
                            _replay!.advance();
                          }),
                          onReset: () => setState(() {
                            _replay!.reset();
                          }),
                        )
                      : _LiveFlightView(
                          platformVersion: _platformVersion ?? 'Unknown',
                          screenManager: _screenManager,
                        ),
                ),
        );
      },
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
          child: Text(message, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

class _LiveFlightView extends StatelessWidget {
  const _LiveFlightView({
    required this.platformVersion,
    required this.screenManager,
  });

  final String platformVersion;
  final ScreenManagerService screenManager;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BrandyFly'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Open Navigation Menu',
          onPressed: () => screenManager.toggleNavBar(true),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note),
            tooltip: 'Enable Edit Mode',
            onPressed: () => screenManager.toggleEditMode(true),
          ),
          const _ModeChip(label: 'LIVE', color: Colors.green),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            title: 'Native platform',
            child: Text('Running on: $platformVersion'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 480,
            child: LayoutStrategyContainer(
              screenManager: screenManager,
              telemetryData: const {
                'altitude': 1250.0,
                'speed': 38.0,
                'glide': 7.5,
                'hag': 280.0,
                'climb': 1.2,
                'windDir': 180.0,
                'windSpeed': 12.0,
                'history': [1200.0, 1220.0, 1235.0, 1250.0],
              },
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
    required this.screenManager,
    required this.onNext,
    required this.onReset,
  });

  final MockFlightModeConfig config;
  final MockFlightReplay replay;
  final ScreenManagerService screenManager;
  final VoidCallback onNext;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final frame = replay.currentFrame;
    return Scaffold(
      appBar: AppBar(
        title: const Text('BrandyFly'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Open Navigation Menu',
          onPressed: () => screenManager.toggleNavBar(true),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note),
            tooltip: 'Enable Edit Mode',
            onPressed: () => screenManager.toggleEditMode(true),
          ),
          const _ModeChip(label: 'SIMULATED', color: Colors.orange),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            title: 'Mock flight session',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Fixture: ${config.fixtureVersion}'),
                Text('Seed: ${config.seed}'),
                Text(
                  'Clock step: ${config.logicalClockStep.inMilliseconds} ms',
                ),
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
                const SizedBox(height: 16),
                SizedBox(
                  height: 380,
                  child: LayoutStrategyContainer(
                    screenManager: screenManager,
                    telemetryData: {
                      'altitude': 1450.0,
                      'speed': 42.5,
                      'glide': 8.4,
                      'hag': 320.0,
                      'climb': 1.8,
                      'windDir': 220.0,
                      'windSpeed': 14.0,
                      'history': [1400.0, 1410.0, 1430.0, 1425.0, 1450.0],
                    },
                  ),
                ),
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
            Text(title, style: Theme.of(context).textTheme.titleMedium),
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
