import 'dart:async';

import 'package:maplibre_platform_interface/maplibre_platform_interface.dart';

import 'support/headless_maplibre.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  MapLibrePlatform.instance = HeadlessMapLibrePlatform();
  await testMain();
}
