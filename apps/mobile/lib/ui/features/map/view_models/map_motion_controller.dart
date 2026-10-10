import 'package:flutter/animation.dart';
import 'package:flutter/scheduler.dart';

import '../../../../domain/map_motion/motion_smoother.dart';
import '../../../../models/lat_lng.dart';

/// Everything the map needs to present one rendered frame.
class MotionFrame {
  const MotionFrame({
    required this.pilot,
    required this.headingDeg,
    required this.cameraCenter,
    required this.zoom,
    required this.bearing,
    required this.topPaddingFraction,
    required this.following,
  });

  /// Smoothed (displayed) pilot position.
  final LatLng pilot;

  /// Filtered pilot heading in [0, 360).
  final double headingDeg;

  /// Camera center to write (the pilot while following).
  final LatLng cameraCenter;
  final double zoom;

  /// Camera bearing in degrees.
  final double bearing;

  /// Top camera padding as a fraction of the viewport height (0 north-up,
  /// [MapMotionController.trackUpTopPadding] track-up). The pilot focal point
  /// sits at `(1 + fraction) / 2` of the height from the top.
  final double topPaddingFraction;

  /// Whether the camera follows the pilot (center-locked).
  final bool following;

  /// Marker rotation relative to the screen (degrees).
  double get markerRotationDeg =>
      MotionSmoother.normalizeDeg(headingDeg - bearing);
}

class _Ease {
  _Ease(this.value);

  double value;
  double _from = 0;
  double _to = 0;
  double? _start;
  double _duration = 0;
  bool _pending = false;

  bool get active => _pending || _start != null;
  double get target => active ? _to : value;

  void animateTo(double to, double durationS) {
    if (durationS <= 0) {
      jumpTo(to);
      return;
    }
    _from = value;
    _to = to;
    _duration = durationS;
    _start = null;
    _pending = true;
  }

  void jumpTo(double to) {
    value = to;
    _start = null;
    _pending = false;
  }

  /// Advances to time [t]; returns the eased progress (1 when idle).
  double advance(double t) {
    if (_pending) {
      _start = t;
      _pending = false;
    }
    final start = _start;
    if (start == null) return 1;
    final p = ((t - start) / _duration).clamp(0.0, 1.0);
    final e = Curves.easeInOut.transform(p);
    value = _from + (_to - _from) * e;
    if (p >= 1) {
      value = _to;
      _start = null;
    }
    return e;
  }
}

/// Drives the map camera at display frame rate from telemetry fixes.
///
/// Fixes are stamped with the frame time of the next vsync, smoothed by
/// [MotionSmoother], and combined with eased zoom / orientation / recenter
/// transitions into exactly one [MotionFrame] per rendered frame. The ticker
/// stops when everything has converged.
class MapMotionController {
  MapMotionController({
    required TickerProvider vsync,
    required this.onFrame,
    double initialZoom = 13.5,
    bool trackUp = false,
    MotionSmoother? smoother,
    this.zoomDuration = const Duration(milliseconds: 250),
    this.recenterDuration = const Duration(milliseconds: 600),
    this.orientationDuration = const Duration(milliseconds: 400),
    this._frameClock,
  }) : _smoother = smoother ?? MotionSmoother(),
       _zoom = _Ease(initialZoom),
       _orientation = _Ease(trackUp ? 1 : 0) {
    _ticker = vsync.createTicker(_onTick);
  }

  /// Top padding fraction in track-up: pilot at 60 % from the top.
  static const double trackUpTopPadding = 0.2;

  final void Function(MotionFrame frame) onFrame;
  final Duration zoomDuration;
  final Duration recenterDuration;
  final Duration orientationDuration;

  final MotionSmoother _smoother;
  final _Ease _zoom;
  final _Ease _orientation;
  final _Ease _recenter = _Ease(1);
  final double Function()? _frameClock;
  late final Ticker _ticker;

  final List<(MotionFix, bool)> _pendingFixes = [];
  MotionFix? _lastPushed;
  bool _following = true;
  bool _forceFrame = false;
  bool _disposed = false;
  LatLng? _recenterFrom;
  double _recenterFromBearing = 0;
  MotionFrame? _lastFrame;

  MotionFrame? get lastFrame => _lastFrame;
  bool get following => _following;
  bool get isTicking => _ticker.isActive;
  double get zoom => _zoom.target;
  MotionSmoother get smoother => _smoother;

  static double _secondsOf(Duration d) => d.inMicroseconds / 1e6;

  double _now() =>
      _frameClock?.call() ??
      _secondsOf(SchedulerBinding.instance.currentFrameTimeStamp);

  /// Feeds a telemetry fix. Identical consecutive fixes are ignored (a
  /// 10 Hz baro stream repeats the 1 Hz GNSS position).
  void pushFix(MotionFix fix, {bool snap = false}) {
    if (_disposed) return;
    if (!snap && fix == _lastPushed) return;
    _lastPushed = fix;
    _pendingFixes.add((fix, snap));
    _ensureTicking();
  }

  /// Changes the zoom (eased unless [animate] is false).
  void setZoom(double zoom, {bool animate = true}) {
    if (_disposed || zoom == _zoom.target) return;
    if (animate) {
      _zoom.animateTo(zoom, _secondsOf(zoomDuration));
    } else {
      _zoom.jumpTo(zoom);
    }
    _forceFrame = true;
    _ensureTicking();
  }

  /// Switches between north-up and track-up (bearing + padding eased).
  void setTrackUp(bool trackUp, {bool animate = true}) {
    if (_disposed) return;
    final to = trackUp ? 1.0 : 0.0;
    if (_orientation.target == to) return;
    if (animate) {
      _orientation.animateTo(to, _secondsOf(orientationDuration));
    } else {
      _orientation.jumpTo(to);
    }
    _forceFrame = true;
    _ensureTicking();
  }

  /// Stops following the pilot (manual pan); the camera is left alone.
  void release() {
    if (_disposed) return;
    _following = false;
    _recenter.jumpTo(1);
    // Emit a frame so the screen marker hides and the native symbol shows.
    _forceFrame = true;
    _ensureTicking();
  }

  /// Resumes following, easing the camera from [from] / [fromBearing] back to
  /// the displayed pilot position.
  void recenter({
    required LatLng from,
    required double fromBearing,
    bool animate = true,
  }) {
    if (_disposed) return;
    _following = true;
    _recenterFrom = from;
    _recenterFromBearing = fromBearing;
    if (animate) {
      _recenter.jumpTo(0);
      _recenter.animateTo(1, _secondsOf(recenterDuration));
    } else {
      _recenter.jumpTo(1);
    }
    _forceFrame = true;
    _ensureTicking();
  }

  /// Requests one frame even if nothing moves (e.g. viewport resized).
  void requestFrame() {
    if (_disposed) return;
    _forceFrame = true;
    _ensureTicking();
  }

  void _ensureTicking() {
    if (!_ticker.isActive) _ticker.start();
  }

  void _onTick(Duration _) {
    if (_disposed) return;
    final t = _now();
    for (final (fix, snap) in _pendingFixes) {
      _smoother.addFix(fix, t, snap: snap);
    }
    _pendingFixes.clear();

    final frame = computeFrame(t);
    _forceFrame = false;
    if (frame != null) {
      _lastFrame = frame;
      onFrame(frame);
    }
    if (_isSettled(t)) _ticker.stop();
  }

  bool _isSettled(double t) =>
      _pendingFixes.isEmpty &&
      !_forceFrame &&
      !_zoom.active &&
      !_orientation.active &&
      !_recenter.active &&
      _smoother.isSettled(t);

  /// Computes the frame for time [t] (exposed for tests).
  MotionFrame? computeFrame(double t) {
    final s = _smoother.sample(t);
    if (s == null) return null;
    _zoom.advance(t);
    final orient = (_orientation..advance(t)).value;
    final pilot = LatLng(s.latitude, s.longitude);
    final targetBearing = MotionSmoother.normalizeDeg(
      MotionSmoother.shortestDelta(0, s.headingDeg) * orient,
    );
    var center = pilot;
    var bearing = targetBearing;
    if (!_following) {
      center = _lastFrame?.cameraCenter ?? pilot;
      bearing = _lastFrame?.bearing ?? targetBearing;
    } else if (_recenter.active) {
      final r = _recenter.advance(t);
      final from = _recenterFrom ?? pilot;
      center = LatLng(
        from.latitude + (pilot.latitude - from.latitude) * r,
        from.longitude + (pilot.longitude - from.longitude) * r,
      );
      bearing = MotionSmoother.normalizeDeg(
        _recenterFromBearing +
            MotionSmoother.shortestDelta(_recenterFromBearing, targetBearing) *
                r,
      );
    }
    return MotionFrame(
      pilot: pilot,
      headingDeg: s.headingDeg,
      cameraCenter: center,
      zoom: _zoom.value,
      bearing: bearing,
      topPaddingFraction: trackUpTopPadding * orient,
      following: _following,
    );
  }

  void dispose() {
    _disposed = true;
    _ticker.dispose();
  }
}
