import 'package:brandyfly_native/audio_vario_models.dart';
import 'package:brandyfly_native/brandyfly_native.dart';

/// Abstract contract for platform-specific audio vario synthesis engines.
abstract class AudioVarioEngine {
  Future<bool> start();
  Future<bool> stop();
  Future<bool> updateTone(AudioToneCommand command);
  Future<bool> setVolume(double volume);
  Future<bool> setMuted(bool isMuted);
  Future<void> pause();
  Future<void> resume();
  void dispose();
}

/// Native audio vario engine routing to Android Oboe/AudioTrack, iOS AVAudioEngine,
/// or Desktop fallback via `BrandyflyNative`.
class NativeAudioVarioEngine implements AudioVarioEngine {
  NativeAudioVarioEngine({BrandyflyNative? native})
      : _native = native ?? const BrandyflyNative();

  final BrandyflyNative _native;
  bool _isRunning = false;
  AudioToneCommand _lastCommand = AudioToneCommand.silent;
  double _volume = 0.8;
  bool _isMuted = false;

  bool get isRunning => _isRunning;
  AudioToneCommand get lastCommand => _lastCommand;

  @override
  Future<bool> start() async {
    _isRunning = true;
    return _native.audioVarioStart();
  }

  @override
  Future<bool> stop() async {
    _isRunning = false;
    _lastCommand = AudioToneCommand.silent;
    return _native.audioVarioStop();
  }

  @override
  Future<bool> updateTone(AudioToneCommand command) async {
    _lastCommand = command;
    if (!_isRunning) return false;
    return _native.audioVarioUpdateTone(command);
  }

  @override
  Future<bool> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    return _native.audioVarioSetVolume(_volume);
  }

  @override
  Future<bool> setMuted(bool isMuted) async {
    _isMuted = isMuted;
    return _native.audioVarioSetMuted(isMuted);
  }

  @override
  Future<void> pause() async {
    if (_isRunning) {
      await _native.audioVarioSetMuted(true);
    }
  }

  @override
  Future<void> resume() async {
    if (_isRunning) {
      await _native.audioVarioSetMuted(_isMuted);
      if (!_isMuted) {
        await _native.audioVarioUpdateTone(_lastCommand);
      }
    }
  }

  @override
  void dispose() {
    stop();
  }
}
