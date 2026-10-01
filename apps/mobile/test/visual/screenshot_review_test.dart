// Visual review screenshots (opt-in): renders flight and edit views of the
// default screens at three canvas sizes with real fonts and writes PNGs to
// build/screenshots/. Run with:
//   SCREENSHOTS=1 flutter test test/visual/screenshot_review_test.dart
@Tags(['screenshots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:brandyfly/domain/models/cockpit_telemetry.dart';
import 'package:brandyfly/domain/models/ui_config.dart';
import 'package:brandyfly/services/screen_manager_service.dart';
import 'package:brandyfly/ui/features/flight_canvas/views/layout_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _loadFonts() async {
  final flutterRoot =
      Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path;
  final materialFonts = '$flutterRoot/bin/cache/artifacts/material_fonts';

  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final file = File(f);
      if (file.existsSync()) {
        loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
      }
    }
    await loader.load();
  }

  await load('Roboto', [
    '$materialFonts/Roboto-Regular.ttf',
    '$materialFonts/Roboto-Medium.ttf',
    '$materialFonts/Roboto-Bold.ttf',
  ]);
  await load('MaterialIcons', ['$materialFonts/MaterialIcons-Regular.otf']);
  final barlow = FontLoader('BarlowSemiCondensed')
    ..addFont(rootBundle.load('assets/fonts/BarlowSemiCondensed-Medium.ttf'))
    ..addFont(rootBundle.load('assets/fonts/BarlowSemiCondensed-Bold.ttf'));
  await barlow.load();
}

void main() {
  final enabled = Platform.environment['SCREENSHOTS'] == '1';

  const canvases = {
    'phone_portrait': Size(390, 844),
    'phone_landscape': Size(844, 390),
    'tablet_landscape': Size(1280, 800),
  };

  testWidgets('capture review screenshots', (tester) async {
    await tester.runAsync(_loadFonts);
    final out = Directory('build/screenshots')..createSync(recursive: true);
    final telemetry = ValueNotifier(
      const CockpitTelemetry(
        altitude: 1873,
        speed: 38.4,
        climb: 2.3,
        hag: 642,
        windDir: 245,
        windSpeed: 17,
        latitude: 47.525,
        longitude: 13.685,
      ),
    );

    for (final screenId in ['normal_flight', 'map_screen']) {
      for (final entry in canvases.entries) {
        for (final mode in ['flight', 'edit']) {
          final manager = ScreenManagerService(
            initialConfig: UIConfig.defaultConfig().copyWith(
              activeScreenId: screenId,
            ),
          );
          if (mode == 'edit') {
            manager.toggleEditMode(true);
            manager.selectWidget(screenId == 'map_screen' ? 'wm_zoom' : 'w1');
          }
          tester.view.physicalSize = entry.value;
          tester.view.devicePixelRatio = 1.0;
          final key = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: key,
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
                    telemetry: telemetry,
                  ),
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 200));
          await tester.runAsync(() async {
            final boundary =
                key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
            File(
              '${out.path}/${screenId}_${entry.key}_$mode.png',
            ).writeAsBytesSync(bytes!.buffer.asUint8List());
          });
          await tester.pumpWidget(const SizedBox());
          manager.dispose();
        }
      }
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }, skip: !enabled);
}
