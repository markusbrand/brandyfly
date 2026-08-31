import 'dart:async';

import 'package:brandyfly_native/brandyfly_native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'models/flight_model.dart';
import 'services/flight_replay_service.dart';
import 'services/flight_storage_service.dart';
import 'services/flight_tracking_service.dart';
import 'services/screen_manager_service.dart';
import 'services/telemetry/synthetic_telemetry_source.dart';
import 'services/ui_persistence_service.dart';
import 'services/xcontest_upload_service.dart';
import 'widgets/flight/flight_summary_sheet.dart';
import 'widgets/flight/flights_screen.dart';
import 'widgets/flight/replay_control_overlay.dart';
import 'widgets/layout/layout_strategy_container.dart';
import 'widgets/navigation/top_nav_bar.dart';
import 'widgets/settings/ui_settings_panel.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();
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
    this.storageService,
    this.trackingService,
    this.replayService,
    this.uploadService,
  });

  final MockFlightModeConfig config;
  final BrandyflyNative native;
  final ScreenManagerService? screenManager;
  final FlightStorageService? storageService;
  final FlightTrackingService? trackingService;
  final FlightReplayService? replayService;
  final XContestUploadService? uploadService;

  @override
  State<BrandyFlyApp> createState() => _BrandyFlyAppState();
}

class _BrandyFlyAppState extends State<BrandyFlyApp> {
  MockFlightReplay? _mockReplay;
  SyntheticTelemetrySource? _syntheticTelemetry;
  Timer? _timer;
  String? _platformVersion;
  String? _startupError;
  bool _loading = true;

  late ScreenManagerService _screenManager;
  late FlightStorageService _storageService;
  late FlightTrackingService _trackingService;
  late FlightReplayService _replayService;
  late XContestUploadService _uploadService;

  StreamSubscription<FlightModel>? _flightCompletedSub;

  @override
  void initState() {
    super.initState();
    _screenManager = widget.screenManager ?? ScreenManagerService();
    _trackingService = widget.trackingService ?? FlightTrackingService();
    _replayService = widget.replayService ?? FlightReplayService();
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

      _storageService = widget.storageService ?? FlightStorageService();
      if (widget.storageService == null) {
        _storageService.initializeSampleFlight().catchError((_) {});
      }

      _uploadService = widget.uploadService ??
          XContestUploadService(
            storageService: _storageService,
            settings: _trackingService.settings,
          );

      _flightCompletedSub = _trackingService.flightCompletedStream.listen((flight) {
        _onFlightCompleted(flight);
      });

      final isNativeSupported = !kIsWeb;
      if (isNativeSupported) {
        try {
          if (widget.config.enabled) {
            await widget.native.configureLocalMockFlightMode(widget.config);
          } else {
            _platformVersion =
                await widget.native.getPlatformVersion() ?? 'Unknown platform version';
          }
        } on MissingPluginException {
          _platformVersion = 'Platform Fallback';
        }
      } else {
        _platformVersion = 'Flutter Web';
      }

      if (widget.config.enabled || kIsWeb) {
        _mockReplay = MockFlightReplay(widget.config);
        _syntheticTelemetry = SyntheticTelemetrySource(
          seed: widget.config.seed.toInt(),
        );
        await _syntheticTelemetry!.initialize();
        _trackingService.attachTelemetrySource(_syntheticTelemetry!);
        _syntheticTelemetry!.start();

        _timer = Timer.periodic(const Duration(seconds: 2), (_) {
          if (!mounted || _mockReplay == null) {
            return;
          }
          setState(() {
            _mockReplay!.advance();
          });
        });
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

  void _onFlightCompleted(FlightModel flight) async {
    await _storageService.saveFlight(flight);
    if (_trackingService.settings.autoUploadToXContest) {
      _uploadService.uploadFlight(flight);
    }
    if (mounted) {
      FlightSummarySheet.show(
        context,
        flight: flight,
        storageService: _storageService,
        uploadService: _uploadService,
        onViewInLogbook: () {
          _screenManager.toggleFlightsScreen(true);
        },
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _syntheticTelemetry?.dispose();
    _flightCompletedSub?.cancel();
    _screenManager.dispose();
    _trackingService.dispose();
    _replayService.dispose();
    super.dispose();
  }

  void _startReplay(FlightModel flight) {
    _replayService.loadFlight(flight);
    _replayService.play();
    _screenManager.toggleFlightsScreen(false);
    _screenManager.toggleReplayMode(true);
  }

  void _exitReplay() {
    _replayService.pause();
    _screenManager.toggleReplayMode(false);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_screenManager, _replayService]),
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
              : _screenManager.isFlightsScreenVisible
              ? FlightsScreen(
                  storageService: _storageService,
                  uploadService: _uploadService,
                  onStartReplay: _startReplay,
                  onClose: () => _screenManager.toggleFlightsScreen(false),
                )
              : Stack(
                  children: [
                    TopNavBarOverlay(
                      screenManager: _screenManager,
                      child: _screenManager.isSettingsVisible
                          ? UISettingsPanel(
                              screenManager: _screenManager,
                              trackingService: _trackingService,
                              uploadService: _uploadService,
                            )
                          : widget.config.enabled
                          ? _MockFlightView(
                              config: widget.config,
                              replay: _mockReplay!,
                              screenManager: _screenManager,
                              replayService: _replayService,
                              onNext: () => setState(() {
                                _mockReplay!.advance();
                              }),
                              onReset: () => setState(() {
                                _mockReplay!.reset();
                              }),
                            )
                          : _LiveFlightView(
                              platformVersion: _platformVersion ?? 'Unknown',
                              screenManager: _screenManager,
                              replayService: _replayService,
                            ),
                    ),

                    // Floating Bottom Replay HUD when Replay Mode is active
                    if (_screenManager.isReplayActive)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: ReplayControlOverlay(
                          replayService: _replayService,
                          onExit: _exitReplay,
                        ),
                      ),
                  ],
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
    required this.replayService,
  });

  final String platformVersion;
  final ScreenManagerService screenManager;
  final FlightReplayService replayService;

  @override
  Widget build(BuildContext context) {
    final isReplaying = screenManager.isReplayActive;
    final telemetry = isReplaying
        ? replayService.currentTelemetry
        : const <String, dynamic>{
            'altitude': 1250.0,
            'speed': 38.0,
            'glide': 7.5,
            'hag': 280.0,
            'climb': 1.2,
            'windDir': 180.0,
            'windSpeed': 12.0,
            'history': [1200.0, 1220.0, 1235.0, 1250.0],
          };

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
          _ModeChip(
            label: isReplaying ? 'REPLAY' : 'LIVE',
            color: isReplaying ? Colors.cyanAccent : Colors.green,
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: isReplaying ? 140 : 16,
        ),
        children: [
          if (!isReplaying) ...[
            _SectionCard(
              title: 'Native platform',
              child: Text('Running on: $platformVersion'),
            ),
            const SizedBox(height: 16),
          ],
          SizedBox(
            height: 480,
            child: LayoutStrategyContainer(
              screenManager: screenManager,
              telemetryData: telemetry,
            ),
          ),
        ],
      ),
    );
  }
}

class _MockFlightView extends StatefulWidget {
  const _MockFlightView({
    required this.config,
    required this.replay,
    required this.screenManager,
    required this.replayService,
    required this.onNext,
    required this.onReset,
  });

  final MockFlightModeConfig config;
  final MockFlightReplay replay;
  final ScreenManagerService screenManager;
  final FlightReplayService replayService;
  final VoidCallback onNext;
  final VoidCallback onReset;

  @override
  State<_MockFlightView> createState() => _MockFlightViewState();
}

class _MockFlightViewState extends State<_MockFlightView> {
  bool _isSessionMinimized = false;

  @override
  Widget build(BuildContext context) {
    final frame = widget.replay.currentFrame;
    final isReplaying = widget.screenManager.isReplayActive;
    final telemetry = isReplaying
        ? widget.replayService.currentTelemetry
        : const <String, dynamic>{
            'altitude': 1450.0,
            'speed': 42.5,
            'glide': 8.4,
            'hag': 320.0,
            'climb': 1.8,
            'windDir': 220.0,
            'windSpeed': 14.0,
            'history': [1400.0, 1410.0, 1430.0, 1425.0, 1450.0],
          };

    return Scaffold(
      appBar: AppBar(
        title: const Text('BrandyFly'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Open Navigation Menu',
          onPressed: () => widget.screenManager.toggleNavBar(true),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note),
            tooltip: 'Enable Edit Mode',
            onPressed: () => widget.screenManager.toggleEditMode(true),
          ),
          _ModeChip(
            label: isReplaying ? 'REPLAY' : 'SIMULATED',
            color: isReplaying ? Colors.cyanAccent : Colors.orange,
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: isReplaying ? 140 : 16,
        ),
        children: [
          if (!isReplaying) ...[
            if (_isSessionMinimized)
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.flight_takeoff, size: 18, color: Colors.orangeAccent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Mock flight session (${widget.config.sessionLabel})',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next, size: 18),
                        tooltip: 'Advance scenario',
                        onPressed: widget.onNext,
                      ),
                      IconButton(
                        icon: const Icon(Icons.restart_alt, size: 18),
                        tooltip: 'Reset replay',
                        onPressed: widget.onReset,
                      ),
                      IconButton(
                        key: const Key('btn_expand_mock_session'),
                        icon: const Icon(Icons.expand_more),
                        tooltip: 'Expand mock flight session',
                        onPressed: () => setState(() => _isSessionMinimized = false),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              _SectionCard(
                title: 'Mock flight session',
                trailing: IconButton(
                  key: const Key('btn_minimize_mock_session'),
                  icon: const Icon(Icons.expand_less),
                  tooltip: 'Minimize mock flight session',
                  onPressed: () => setState(() => _isSessionMinimized = true),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Fixture: ${widget.config.fixtureVersion}'),
                    Text('Seed: ${widget.config.seed}'),
                    Text(
                      'Clock step: ${widget.config.logicalClockStep.inMilliseconds} ms',
                    ),
                    Text('Provenance: ${widget.config.provenance}'),
                    Text('Session label: ${widget.config.sessionLabel}'),
                    Text('Replay hash: ${widget.replay.canonicalReplayHash}'),
                    Text('Marker: ${frame.sessionMarker}'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: widget.onNext,
                    child: const Text('Advance scenario'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: widget.onReset,
                    child: const Text('Reset replay'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
          ],
          _SectionCard(
            title: isReplaying
                ? 'Replaying: ${widget.replayService.flight?.title ?? "Flight"}'
                : frame.title,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isReplaying) ...[
                  _FeatureLine(
                    label: 'Telemetry',
                    value: frame.telemetrySummary,
                  ),
                  const SizedBox(height: 16),
                ],
                SizedBox(
                  height: _isSessionMinimized ? 520 : 380,
                  child: LayoutStrategyContainer(
                    screenManager: widget.screenManager,
                    telemetryData: telemetry,
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
  const _SectionCard({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(title, style: Theme.of(context).textTheme.titleMedium),
                ),
                ?trailing,
              ],
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
