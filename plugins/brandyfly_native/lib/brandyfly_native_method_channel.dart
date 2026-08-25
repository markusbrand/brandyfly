import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'brandyfly_native_platform_interface.dart';
import 'mock_flight_mode.dart';

/// An implementation of [BrandyflyNativePlatform] that uses method channels.
class MethodChannelBrandyflyNative extends BrandyflyNativePlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('brandyfly_native');

  @override
  Future<String?> getPlatformVersion() async {
    try {
      final version = await methodChannel.invokeMethod<String>(
        'getPlatformVersion',
      );
      return version;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<void> configureLocalMockFlightMode(MockFlightModeConfig config) async {
    try {
      await methodChannel.invokeMethod<void>(
        'configureLocalMockFlightMode',
        config.toMap(),
      );
    } on MissingPluginException {
      // Fallback on platforms where native method channel is unhandled
    }
  }

  @override
  Future<int?> getMonotonicTimeNanos() async {
    try {
      final nanos = await methodChannel.invokeMethod<int>(
        'getMonotonicTimeNanos',
      );
      return nanos;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<Map<String, Object?>?> runNativeBenchmark() async {
    try {
      final result = await methodChannel.invokeMapMethod<String, Object?>(
        'runNativeBenchmark',
      );
      return result;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<bool> startSkyDrop1Transport({
    bool developerModeOnly = true,
    String? deviceAddress,
  }) async {
    try {
      final res = await methodChannel.invokeMethod<bool>(
        'startSkyDrop1Transport',
        {
          'developerModeOnly': developerModeOnly,
          'deviceAddress': deviceAddress,
        },
      );
      return res ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> stopSkyDrop1Transport() async {
    try {
      await methodChannel.invokeMethod<void>('stopSkyDrop1Transport');
    } on MissingPluginException {
      // no-op
    }
  }

  @override
  Future<Map<String, Object?>?> runSkyDrop1HardwareBenchmark() async {
    try {
      final result = await methodChannel.invokeMapMethod<String, Object?>(
        'runSkyDrop1HardwareBenchmark',
      );
      return result;
    } on MissingPluginException {
      return null;
    }
  }
}
