import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'airspace_models.dart';
import 'audio_vario_models.dart';
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

  int _fallbackAirspaceCount = 0;

  @override
  Future<int> airspaceInitStore() async {
    try {
      final res = await methodChannel.invokeMethod<int>('airspaceInitStore');
      _fallbackAirspaceCount = res ?? 0;
      return res ?? 0;
    } on MissingPluginException {
      _fallbackAirspaceCount = 0;
      return 1;
    }
  }

  @override
  Future<int> airspaceLoadOpenAir(String openAirText) async {
    try {
      final res = await methodChannel.invokeMethod<int>(
        'airspaceLoadOpenAir',
        {'openAirText': openAirText},
      );
      _fallbackAirspaceCount = res ?? 0;
      return res ?? 0;
    } on MissingPluginException {
      // In-memory fallback: count AC records
      final matches = RegExp(r'^\s*AC\s+', multiLine: true).allMatches(openAirText);
      _fallbackAirspaceCount = matches.length;
      return _fallbackAirspaceCount;
    }
  }

  @override
  Future<int> airspaceLoadDachFixture() async {
    try {
      final res =
          await methodChannel.invokeMethod<int>('airspaceLoadDachFixture');
      _fallbackAirspaceCount = res ?? 0;
      return res ?? 0;
    } on MissingPluginException {
      _fallbackAirspaceCount = 7;
      return 7;
    }
  }

  @override
  Future<int> airspaceClearStore() async {
    try {
      final res = await methodChannel.invokeMethod<int>('airspaceClearStore');
      _fallbackAirspaceCount = 0;
      return res ?? 0;
    } on MissingPluginException {
      _fallbackAirspaceCount = 0;
      return 0;
    }
  }

  @override
  Future<int> airspaceCount() async {
    try {
      final res = await methodChannel.invokeMethod<int>('airspaceCount');
      return res ?? _fallbackAirspaceCount;
    } on MissingPluginException {
      return _fallbackAirspaceCount;
    }
  }

  @override
  Future<NativeAirspaceEvaluationOutput> airspaceEvaluate(
    NativeAirspaceEvaluationInput input,
  ) async {
    try {
      final res = await methodChannel.invokeMapMethod<String, Object?>(
        'airspaceEvaluate',
        input.toMap(),
      );
      if (res != null) {
        return NativeAirspaceEvaluationOutput.fromMap(res);
      }
      return NativeAirspaceEvaluationOutput.clear;
    } on MissingPluginException {
      return NativeAirspaceEvaluationOutput.clear;
    }
  }

  bool _fallbackAudioRunning = false;
  AudioToneCommand _fallbackAudioCommand = AudioToneCommand.silent;
  double _fallbackVolume = 0.8;
  bool _fallbackMuted = false;

  @visibleForTesting
  AudioToneCommand get fallbackAudioCommand => _fallbackAudioCommand;

  @visibleForTesting
  bool get fallbackAudioRunning => _fallbackAudioRunning;

  @override
  Future<bool> audioVarioStart() async {
    try {
      final res = await methodChannel.invokeMethod<bool>('audioVarioStart');
      _fallbackAudioRunning = res ?? true;
      return res ?? true;
    } on MissingPluginException {
      _fallbackAudioRunning = true;
      return true;
    }
  }

  @override
  Future<bool> audioVarioStop() async {
    try {
      final res = await methodChannel.invokeMethod<bool>('audioVarioStop');
      _fallbackAudioRunning = false;
      return res ?? true;
    } on MissingPluginException {
      _fallbackAudioRunning = false;
      _fallbackAudioCommand = AudioToneCommand.silent;
      return true;
    }
  }

  @override
  Future<bool> audioVarioUpdateTone(AudioToneCommand command) async {
    _fallbackAudioCommand = command;
    try {
      final res = await methodChannel.invokeMethod<bool>(
        'audioVarioUpdateTone',
        command.toMap(),
      );
      return res ?? true;
    } on MissingPluginException {
      return true;
    }
  }

  @override
  Future<bool> audioVarioSetVolume(double volume) async {
    _fallbackVolume = volume.clamp(0.0, 1.0);
    try {
      final res = await methodChannel.invokeMethod<bool>(
        'audioVarioSetVolume',
        {'volume': _fallbackVolume},
      );
      return res ?? true;
    } on MissingPluginException {
      return true;
    }
  }

  @override
  Future<bool> audioVarioSetMuted(bool isMuted) async {
    _fallbackMuted = isMuted;
    try {
      final res = await methodChannel.invokeMethod<bool>(
        'audioVarioSetMuted',
        {'isMuted': isMuted},
      );
      return res ?? true;
    } on MissingPluginException {
      return true;
    }
  }
}
