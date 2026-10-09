import 'airspace_models.dart';
import 'audio_vario_models.dart';
import 'brandyfly_native_platform_interface.dart';
import 'mock_flight_mode.dart';

export 'airspace_models.dart';
export 'audio_vario_models.dart';
export 'mock_flight_mode.dart';
export 'skydrop1_models.dart';

class BrandyflyNative {
  const BrandyflyNative();

  Future<String?> getPlatformVersion() {
    return BrandyflyNativePlatform.instance.getPlatformVersion();
  }

  Future<void> configureLocalMockFlightMode(
    MockFlightModeConfig config,
  ) {
    return BrandyflyNativePlatform.instance.configureLocalMockFlightMode(
      config,
    );
  }

  Future<int?> getMonotonicTimeNanos() {
    return BrandyflyNativePlatform.instance.getMonotonicTimeNanos();
  }

  Future<Map<String, Object?>?> runNativeBenchmark() {
    return BrandyflyNativePlatform.instance.runNativeBenchmark();
  }

  Future<bool> startSkyDrop1Transport({
    bool developerModeOnly = true,
    String? deviceAddress,
  }) {
    return BrandyflyNativePlatform.instance.startSkyDrop1Transport(
      developerModeOnly: developerModeOnly,
      deviceAddress: deviceAddress,
    );
  }

  Future<void> stopSkyDrop1Transport() {
    return BrandyflyNativePlatform.instance.stopSkyDrop1Transport();
  }

  Future<Map<String, Object?>?> runSkyDrop1HardwareBenchmark() {
    return BrandyflyNativePlatform.instance.runSkyDrop1HardwareBenchmark();
  }

  Future<int> airspaceInitStore() {
    return BrandyflyNativePlatform.instance.airspaceInitStore();
  }

  Future<int> airspaceLoadOpenAir(String openAirText) {
    return BrandyflyNativePlatform.instance.airspaceLoadOpenAir(openAirText);
  }

  Future<int> airspaceLoadDachFixture() {
    return BrandyflyNativePlatform.instance.airspaceLoadDachFixture();
  }

  Future<int> airspaceClearStore() {
    return BrandyflyNativePlatform.instance.airspaceClearStore();
  }

  Future<int> airspaceCount() {
    return BrandyflyNativePlatform.instance.airspaceCount();
  }

  Future<NativeAirspaceEvaluationOutput> airspaceEvaluate(
    NativeAirspaceEvaluationInput input,
  ) {
    return BrandyflyNativePlatform.instance.airspaceEvaluate(input);
  }

  Future<bool> audioVarioStart() {
    return BrandyflyNativePlatform.instance.audioVarioStart();
  }

  Future<bool> audioVarioStop() {
    return BrandyflyNativePlatform.instance.audioVarioStop();
  }

  Future<bool> audioVarioUpdateTone(AudioToneCommand command) {
    return BrandyflyNativePlatform.instance.audioVarioUpdateTone(command);
  }

  Future<bool> audioVarioSetVolume(double volume) {
    return BrandyflyNativePlatform.instance.audioVarioSetVolume(volume);
  }

  Future<bool> audioVarioSetMuted(bool isMuted) {
    return BrandyflyNativePlatform.instance.audioVarioSetMuted(isMuted);
  }
}
