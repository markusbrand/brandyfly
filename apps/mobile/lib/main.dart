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
      body: Stack(
        children: [
          // Full-screen Flight Screen & Instrument Layout
          Positioned.fill(
            child: LayoutStrategyContainer(
              screenManager: screenManager,
              telemetryData: telemetry,
            ),
          ),

          // Floating Top-Right Mode & Platform Status Overlay
          Positioned(
            top: 8,
            right: 8,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(180),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isReplaying
                        ? Colors.cyanAccent.withAlpha(120)
                        : Colors.greenAccent.withAlpha(120),
                    width: 1,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'BrandyFly',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _ModeChip(
                      label: isReplaying ? 'REPLAY' : 'LIVE',
                      color: isReplaying ? Colors.cyanAccent : Colors.green,
                    ),
                    if (!isReplaying) ...[
                      const SizedBox(width: 4),
                      Text(
                        'Running on: $platformVersion',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
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
      body: Stack(
        children: [
          // Full-screen Flight Screen & Instrument Layout
          Positioned.fill(
            child: LayoutStrategyContainer(
              screenManager: widget.screenManager,
              telemetryData: telemetry,
            ),
          ),

          // Floating Top-Right Mock Flight Session & Mode Controller Overlay
          Positioned(
            top: 8,
            right: 8,
            child: SafeArea(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 360),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade900.withAlpha(220),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isReplaying
                        ? Colors.cyanAccent.withAlpha(140)
                        : Colors.orangeAccent.withAlpha(140),
                    width: 1.2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'BrandyFly',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          _ModeChip(
                            label: isReplaying ? 'REPLAY' : 'SIMULATED',
                            color: isReplaying ? Colors.cyanAccent : Colors.orange,
                          ),
                          if (!isReplaying) ...[
                            IconButton(
                              icon: const Icon(
                                Icons.skip_next,
                                size: 16,
                                color: Colors.orangeAccent,
                              ),
                              padding: const EdgeInsets.all(2),
                              constraints: const BoxConstraints(),
                              tooltip: 'Advance scenario',
                              onPressed: widget.onNext,
                            ),
                            const SizedBox(width: 2),
                            IconButton(
                              icon: const Icon(
                                Icons.restart_alt,
                                size: 16,
                                color: Colors.white70,
                              ),
                              padding: const EdgeInsets.all(2),
                              constraints: const BoxConstraints(),
                              tooltip: 'Reset replay',
                              onPressed: widget.onReset,
                            ),
                            const SizedBox(width: 2),
                            IconButton(
                              key: Key(
                                _isSessionMinimized
                                    ? 'btn_expand_mock_session'
                                    : 'btn_minimize_mock_session',
                              ),
                              icon: Icon(
                                _isSessionMinimized
                                    ? Icons.expand_more
                                    : Icons.expand_less,
                                size: 18,
                                color: Colors.white70,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: _isSessionMinimized
                                  ? 'Expand mock flight session'
                                  : 'Minimize mock flight session',
                              onPressed: () => setState(
                                () => _isSessionMinimized = !_isSessionMinimized,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (!isReplaying && _isSessionMinimized) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Mock flight session (${widget.config.sessionLabel})',
                        style: const TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                    if (!isReplaying && !_isSessionMinimized) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Mock flight session (${widget.config.sessionLabel})',
                              style: const TextStyle(
                                color: Colors.orangeAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Fixture: ${widget.config.fixtureVersion}',
                              style: const TextStyle(
                                fontSize: 8.5,
                                color: Colors.white70,
                              ),
                            ),
                            Text(
                              'Seed: ${widget.config.seed}',
                              style: const TextStyle(
                                fontSize: 8.5,
                                color: Colors.white70,
                              ),
                            ),
                            Text(
                              'Clock step: ${widget.config.logicalClockStep.inMilliseconds} ms',
                              style: const TextStyle(
                                fontSize: 8.5,
                                color: Colors.white70,
                              ),
                            ),
                            Text(
                              'Provenance: ${widget.config.provenance}',
                              style: const TextStyle(
                                fontSize: 8.5,
                                color: Colors.white70,
                              ),
                            ),
                            Text(
                              'Session label: ${widget.config.sessionLabel}',
                              style: const TextStyle(
                                fontSize: 8.5,
                                color: Colors.white70,
                              ),
                            ),
                            Text(
                              'Replay hash: ${widget.replay.canonicalReplayHash}',
                              style: const TextStyle(
                                fontSize: 8.5,
                                color: Colors.white70,
                              ),
                            ),
                            Text(
                              'Marker: ${frame.sessionMarker}',
                              style: const TextStyle(
                                fontSize: 8.5,
                                color: Colors.white70,
                              ),
                            ),
                            Text(
                              frame.title,
                              style: const TextStyle(
                                fontSize: 8.5,
                                color: Colors.cyanAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(40),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

