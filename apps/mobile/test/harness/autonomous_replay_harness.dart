import 'dart:io';
import 'dart:ui' as ui;

import 'package:brandyfly/domain/models/ui_config.dart';
import 'package:brandyfly/services/screen_manager_service.dart';
import 'package:brandyfly/ui/features/flight_canvas/views/layout_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'invariant_checker.dart';
import 'report_generator.dart';
import 'scenario_catalog.dart';
import 'telemetry_driver.dart';

/// Configuration options for an autonomous replay test run.
class HarnessConfig {
  const HarnessConfig({
    this.canvases = defaultCanvases,
    this.screenIds = const ['normal_flight'],
    this.captureScreenshots = false,
    this.reportPath = ReplayReportGenerator.defaultReportPath,
    this.screenshotsDir = 'build/harness/screenshots',
    this.uiConfig,
    this.remountPerScenario = false,
  });

  static const Map<String, Size> defaultCanvases = {
    'phone_portrait': Size(390, 844),
    'phone_landscape': Size(844, 390),
    'tablet_landscape': Size(1280, 800),
  };

  /// Canvas matrix to test (e.g. phone portrait, phone landscape, tablet).
  final Map<String, Size> canvases;

  /// Screen IDs to render from [uiConfig] or default configuration.
  final List<String> screenIds;

  /// Whether to capture milestone keyframe PNGs.
  final bool captureScreenshots;

  /// Target path for the output JSON report.
  final String reportPath;

  /// Target directory for milestone screenshots.
  final String screenshotsDir;

  /// Optional custom UI configuration. If omitted, uses [UIConfig.defaultConfig()].
  final UIConfig? uiConfig;

  /// Whether to remount the widget tree for each scenario, or keep the mounted
  /// cockpit active while streaming scenarios sequentially through it.
  final bool remountPerScenario;
}

/// Autonomous Replay Harness runner for headless regression verification.
class AutonomousReplayHarness {
  AutonomousReplayHarness({
    LayoutInvariantChecker? invariantChecker,
    ReplayReportGenerator? reportGenerator,
    HarnessTelemetryDriver? driver,
  })  : invariantChecker = invariantChecker ?? LayoutInvariantChecker(),
        reportGenerator = reportGenerator ?? const ReplayReportGenerator(),
        driver = driver ?? HarnessTelemetryDriver();

  final LayoutInvariantChecker invariantChecker;
  final ReplayReportGenerator reportGenerator;
  final HarnessTelemetryDriver driver;

  /// Loads bundled fonts (Roboto, MaterialIcons, BarlowSemiCondensed) into the
  /// Flutter test environment for authentic text bounding box calculations.
  static Future<void> loadFonts() async {
    final flutterRoot = Platform.environment['FLUTTER_ROOT'] ??
        File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path;
    final materialFonts = '$flutterRoot/bin/cache/artifacts/material_fonts';

    Future<void> load(String family, List<String> files) async {
      final loader = FontLoader(family);
      var added = false;
      for (final f in files) {
        final file = File(f);
        if (file.existsSync()) {
          loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
          added = true;
        }
      }
      if (added) {
        await loader.load();
      }
    }

    await load('Roboto', [
      '$materialFonts/Roboto-Regular.ttf',
      '$materialFonts/Roboto-Medium.ttf',
      '$materialFonts/Roboto-Bold.ttf',
    ]);
    await load('MaterialIcons', ['$materialFonts/MaterialIcons-Regular.otf']);

    try {
      final barlow = FontLoader('BarlowSemiCondensed')
        ..addFont(rootBundle.load('assets/fonts/BarlowSemiCondensed-Medium.ttf'))
        ..addFont(rootBundle.load('assets/fonts/BarlowSemiCondensed-Bold.ttf'));
      await barlow.load();
    } catch (_) {
      // Barlow font loading is best-effort in environments where asset bundles differ.
    }
  }

  /// Executes an entire scenario suite across the canvas matrix, asserts
  /// invariants, collects milestone artifacts, and writes a structured report.
  Future<ReplayReport> runSuite({
    required WidgetTester tester,
    List<ReplayScenario>? scenarios,
    HarnessConfig config = const HarnessConfig(),
  }) async {
    final stopwatch = Stopwatch()..start();
    final activeScenarios = scenarios ?? ScenarioCatalog.all;
    final recordedMilestones = <MilestoneArtifact>[];

    invariantChecker.startCollecting();

    try {
      for (final screenId in config.screenIds) {
        for (final canvasEntry in config.canvases.entries) {
          final canvasName = canvasEntry.key;
          final canvasSize = canvasEntry.value;

          if (config.remountPerScenario) {
            for (final scenario in activeScenarios) {
              await _runScenarioOnMountedCanvas(
                tester: tester,
                scenario: scenario,
                canvasName: canvasName,
                canvasSize: canvasSize,
                screenId: screenId,
                config: config,
                recordedMilestones: recordedMilestones,
                mountFresh: true,
              );
            }
          } else {
            // Mount once per screen and canvas for optimal performance
            final baseConfig = config.uiConfig ?? UIConfig.defaultConfig();
            final manager = ScreenManagerService(
              initialConfig: baseConfig.copyWith(activeScreenId: screenId),
            );

            tester.view.physicalSize = canvasSize;
            tester.view.devicePixelRatio = 1.0;

            final boundaryKey = GlobalKey();

            await tester.pumpWidget(
              RepaintBoundary(
                key: boundaryKey,
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: ThemeData(
                    brightness: Brightness.dark,
                    fontFamily: 'Roboto',
                  ),
                  home: Scaffold(
                    backgroundColor: const Color(0xFF16202A),
                    body: LayoutStrategyContainer(
                      screenManager: manager,
                      telemetry: driver.telemetryNotifier,
                    ),
                  ),
                ),
              ),
            );
            await tester.pump(const Duration(milliseconds: 50));

            for (final scenario in activeScenarios) {
              await _playbackScenario(
                tester: tester,
                scenario: scenario,
                canvasName: canvasName,
                boundaryKey: boundaryKey,
                config: config,
                recordedMilestones: recordedMilestones,
              );
            }

            await tester.pumpWidget(const SizedBox());
            manager.dispose();
          }
        }
      }
    } finally {
      invariantChecker.stopCollecting();
      stopwatch.stop();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }

    final report = reportGenerator.buildReport(
      scenarios: activeScenarios.map((s) => s.id).toList(),
      canvasTested: config.canvases.keys.toList(),
      failures: invariantChecker.violations,
      milestones: recordedMilestones,
      executionDurationMs: stopwatch.elapsedMilliseconds,
    );

    reportGenerator.writeReport(report, path: config.reportPath);
    return report;
  }

  /// Run a single scenario on a specific canvas.
  Future<void> _runScenarioOnMountedCanvas({
    required WidgetTester tester,
    required ReplayScenario scenario,
    required String canvasName,
    required Size canvasSize,
    required String screenId,
    required HarnessConfig config,
    required List<MilestoneArtifact> recordedMilestones,
    required bool mountFresh,
  }) async {
    final baseConfig = config.uiConfig ?? UIConfig.defaultConfig();
    final manager = ScreenManagerService(
      initialConfig: baseConfig.copyWith(activeScreenId: screenId),
    );

    tester.view.physicalSize = canvasSize;
    tester.view.devicePixelRatio = 1.0;

    final boundaryKey = GlobalKey();

    driver.loadScenario(scenario);

    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.dark,
            fontFamily: 'Roboto',
          ),
          home: Scaffold(
            backgroundColor: const Color(0xFF16202A),
            body: LayoutStrategyContainer(
              screenManager: manager,
              telemetry: driver.telemetryNotifier,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    await _playbackScenario(
      tester: tester,
      scenario: scenario,
      canvasName: canvasName,
      boundaryKey: boundaryKey,
      config: config,
      recordedMilestones: recordedMilestones,
    );

    if (mountFresh) {
      await tester.pumpWidget(const SizedBox());
      manager.dispose();
    }
  }

  /// Streams time-stepped telemetry through the mounted widget tree.
  Future<void> _playbackScenario({
    required WidgetTester tester,
    required ReplayScenario scenario,
    required String canvasName,
    required GlobalKey boundaryKey,
    required HarnessConfig config,
    required List<MilestoneArtifact> recordedMilestones,
  }) async {
    driver.loadScenario(scenario);

    for (final step in scenario.steps) {
      driver.jumpTo(step.elapsed);
      invariantChecker.setContext(
        scenarioId: scenario.id,
        canvasName: canvasName,
        milestone: step.milestone,
      );

      await tester.pump(const Duration(milliseconds: 20));

      final root = tester.binding.rootElement?.renderObject;
      if (root != null) {
        invariantChecker.inspectRenderTree(root);
      }

      if (step.milestone != null) {
        String? screenshotPath;
        if (config.captureScreenshots) {
          screenshotPath =
              '${config.screenshotsDir}/${scenario.id}_${canvasName}_${step.milestone}.png';
          await tester.runAsync(() async {
            final boundary = boundaryKey.currentContext?.findRenderObject()
                as RenderRepaintBoundary?;
            if (boundary != null) {
              final image = await boundary.toImage();
              final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
              if (bytes != null) {
                final file = File(screenshotPath!);
                file.parent.createSync(recursive: true);
                file.writeAsBytesSync(bytes.buffer.asUint8List());
              }
            }
          });
        }

        recordedMilestones.add(
          MilestoneArtifact(
            scenario: scenario.id,
            canvas: canvasName,
            milestone: step.milestone!,
            screenshot: screenshotPath,
          ),
        );
      }
    }
  }
}
