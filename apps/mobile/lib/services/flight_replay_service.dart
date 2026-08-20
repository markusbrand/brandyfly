import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/flight_model.dart';

class FlightReplayService extends ChangeNotifier {
  FlightReplayService({
    FlightModel? flight,
  }) {
    if (flight != null) {
      loadFlight(flight);
    }
  }

  FlightModel? _flight;
  int _currentIndex = 0;
  bool _isPlaying = false;
  int _speedMultiplier = 1; // 1x, 2x, 3x, 4x, 5x, 6x, 7x, 8x
  Timer? _playbackTimer;

  final List<double> _altitudeHistory = [];

  FlightModel? get flight => _flight;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;
  int get speedMultiplier => _speedMultiplier;
  int get totalPoints => _flight?.points.length ?? 0;

  FlightPoint? get currentPoint {
    if (_flight == null || _flight!.points.isEmpty) return null;
    if (_currentIndex < 0 || _currentIndex >= _flight!.points.length) {
      return _flight!.points.first;
    }
    return _flight!.points[_currentIndex];
  }

  double get progressRatio {
    if (totalPoints <= 1) return 0.0;
    return (_currentIndex / (totalPoints - 1)).clamp(0.0, 1.0);
  }

  Duration get elapsedDuration {
    if (_flight == null || _flight!.points.isEmpty || _currentIndex <= 0) {
      return Duration.zero;
    }
    final first = _flight!.points.first.timestamp;
    final cur = currentPoint?.timestamp ?? first;
    return cur.difference(first);
  }

  Duration get totalDuration {
    return _flight?.statistics.duration ?? Duration.zero;
  }

  Map<String, dynamic> get currentTelemetry {
    final pt = currentPoint;
    if (pt == null) {
      return {
        'altitude': 1250.0,
        'speed': 38.0,
        'glide': 7.5,
        'hag': 280.0,
        'climb': 1.2,
        'windDir': 180.0,
        'windSpeed': 12.0,
        'latitude': 47.5246,
        'longitude': 13.6917,
        'heading': 0.0,
        'history': <double>[1250.0],
      };
    }

    return {
      'altitude': pt.altitude,
      'speed': pt.speed,
      'glide': 8.0,
      'hag': pt.hag ?? (pt.altitude - 800.0).clamp(0.0, 9999.0),
      'climb': pt.vario,
      'windDir': (pt.heading + 180.0) % 360.0,
      'windSpeed': 12.0,
      'latitude': pt.latitude,
      'longitude': pt.longitude,
      'heading': pt.heading,
      'history': List<double>.from(_altitudeHistory),
    };
  }

  void loadFlight(FlightModel flight) {
    pause();
    _flight = flight;
    _currentIndex = 0;
    _altitudeHistory.clear();
    if (flight.points.isNotEmpty) {
      _altitudeHistory.add(flight.points.first.altitude);
    }
    notifyListeners();
  }

  void play() {
    if (_isPlaying || _flight == null || _flight!.points.isEmpty) return;
    _isPlaying = true;
    _startTimer();
    notifyListeners();
  }

  void pause() {
    _isPlaying = false;
    _playbackTimer?.cancel();
    _playbackTimer = null;
    notifyListeners();
  }

  void togglePlayPause() {
    if (_isPlaying) {
      pause();
    } else {
      play();
    }
  }

  void cycleSpeedMultiplier() {
    // Cycles 1x -> 2x -> 3x -> 4x -> 5x -> 6x -> 7x -> 8x -> 1x
    if (_speedMultiplier >= 8) {
      _speedMultiplier = 1;
    } else {
      _speedMultiplier += 1;
    }
    if (_isPlaying) {
      _startTimer();
    }
    notifyListeners();
  }

  void setSpeedMultiplier(int speed) {
    _speedMultiplier = speed.clamp(1, 8);
    if (_isPlaying) {
      _startTimer();
    }
    notifyListeners();
  }

  void seekTo(int index) {
    if (_flight == null || _flight!.points.isEmpty) return;
    _currentIndex = index.clamp(0, _flight!.points.length - 1);
    _rebuildAltitudeHistory();
    notifyListeners();
  }

  void seekToRatio(double ratio) {
    if (_flight == null || _flight!.points.isEmpty) return;
    final target = (ratio * (_flight!.points.length - 1)).round();
    seekTo(target);
  }

  void advance([int steps = 1]) {
    if (_flight == null || _flight!.points.isEmpty) return;
    if (_currentIndex + steps >= _flight!.points.length) {
      _currentIndex = _flight!.points.length - 1;
      pause();
    } else {
      _currentIndex += steps;
    }
    _rebuildAltitudeHistory();
    notifyListeners();
  }

  void _rebuildAltitudeHistory() {
    if (_flight == null || _flight!.points.isEmpty) return;
    _altitudeHistory.clear();
    final start = (_currentIndex - 20).clamp(0, _currentIndex);
    for (var i = start; i <= _currentIndex; i++) {
      _altitudeHistory.add(_flight!.points[i].altitude);
    }
  }

  void _startTimer() {
    _playbackTimer?.cancel();
    // Interval scaled by speed multiplier: 1000ms / speed (min 100ms)
    final intervalMs = (1000 / _speedMultiplier).round().clamp(50, 1000);
    _playbackTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      if (_flight == null || _currentIndex >= _flight!.points.length - 1) {
        pause();
        return;
      }
      advance(1);
    });
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }
}
