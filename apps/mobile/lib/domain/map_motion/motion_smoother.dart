import 'dart:math' as math;

/// One telemetry fix fed into the [MotionSmoother].
class MotionFix {
  const MotionFix({
    required this.latitude,
    required this.longitude,
    this.headingDeg,
    this.speedKmh,
    this.stale = false,
  });

  final double latitude;
  final double longitude;

  /// Course over ground in degrees (null = unknown).
  final double? headingDeg;

  /// Ground speed in km/h (null = unknown). Below
  /// [MotionSmoother.groundSpeedHoldKmh] the heading is held.
  final double? speedKmh;

  /// Stale or invalid fixes freeze the display instead of moving it.
  final bool stale;

  @override
  bool operator ==(Object other) =>
      other is MotionFix &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.headingDeg == headingDeg &&
      other.speedKmh == speedKmh &&
      other.stale == stale;

  @override
  int get hashCode =>
      Object.hash(latitude, longitude, headingDeg, speedKmh, stale);
}

/// Smoothed pilot state to present at one instant.
class MotionSample {
  const MotionSample(this.latitude, this.longitude, this.headingDeg);

  final double latitude;
  final double longitude;

  /// Filtered heading normalized to [0, 360).
  final double headingDeg;

  @override
  String toString() =>
      'MotionSample(${latitude.toStringAsFixed(6)}, '
      '${longitude.toStringAsFixed(6)}, ${headingDeg.toStringAsFixed(1)}°)';
}

class _HistoryEntry {
  const _HistoryEntry(this.t, this.latitude, this.longitude);
  final double t;
  final double latitude;
  final double longitude;
}

/// Presentation-only motion smoothing for the flight map.
///
/// Pure Dart and deterministic: the output depends only on the sequence of
/// `(fix, time)` inputs and the sample time, never on frame rate or wall
/// clock, so it can be unit tested with synthetic timelines.
///
/// Position: velocity is estimated from the observed fix motion (wall-clock
/// arrival time, so replay multipliers work automatically) and the target is
/// extrapolated for at most [horizonIntervals] observed fix intervals and
/// never longer than [predictionHorizon] seconds (so a paused replay or a GNSS
/// dropout overshoots by at most half a fix interval). When a new fix
/// arrives, the difference between the displayed and the new position decays
/// exponentially ([convergenceTau]) so there is no visible jump. Fixes more
/// than [snapDistanceM] away snap immediately.
///
/// Heading: an alpha-beta filter (angle + turn rate) on the unwrapped course
/// removes fix-to-fix jitter while tracking steady turns without lag; the
/// display blends onto each new estimate with [headingTau].
class MotionSmoother {
  MotionSmoother({
    this.predictionHorizon = 2.0,
    this.horizonIntervals = 1.5,
    this.convergenceTau = 0.12,
    this.snapDistanceM = 300.0,
    this.velocityBaseline = 0.5,
    this.maxVelocityGap = 3.0,
    this.maxSpeedMps = 200.0,
    this.headingAlpha = 0.5,
    this.headingBeta = 0.15,
    this.headingTau = 0.25,
    this.maxTurnRateDegS = 90.0,
    this.groundSpeedHoldKmh = 5.0,
  });

  /// Max seconds a position/heading is extrapolated after the last fix.
  final double predictionHorizon;

  /// Prediction horizon in multiples of the observed fix interval.
  final double horizonIntervals;

  /// Time constant (s) of the blend from displayed to new fix trajectory.
  final double convergenceTau;

  /// Distance (m) above which a new fix snaps instead of blending.
  final double snapDistanceM;

  /// Minimum span (s) over which velocity is measured (reduces
  /// frame-quantization noise of arrival timestamps for high-rate sources).
  final double velocityBaseline;

  /// Max gap (s) between fixes that still yields a velocity estimate.
  final double maxVelocityGap;

  /// Upper bound of the estimated speed (m/s), guards against bad timing.
  final double maxSpeedMps;

  /// Alpha-beta heading gains, referenced to a 1 s fix interval.
  final double headingAlpha;
  final double headingBeta;

  /// Time constant (s) of the heading display blend.
  final double headingTau;

  /// Clamp of the estimated turn rate (deg/s).
  final double maxTurnRateDegS;

  /// Ground speed (km/h) below which the heading is held.
  final double groundSpeedHoldKmh;

  static const double _metersPerDegLat = 111320.0;

  // Position state (valid when _t0 != null).
  double? _t0;
  double _lat0 = 0;
  double _lon0 = 0;
  double _vE = 0; // m/s east
  double _vN = 0; // m/s north
  double _eE = 0; // display offset at _t0 (m east)
  double _eN = 0; // display offset at _t0 (m north)
  final List<_HistoryEntry> _history = [];

  // Heading state (unwrapped degrees).
  double? _ht; // time of last heading update
  double _hA = 0; // filtered angle at _ht
  double _hR = 0; // filtered turn rate (deg/s)
  double _hOff = 0; // display offset at _ht

  bool _stale = false;

  // Smoothed interval between fixes (s) and the resulting horizon.
  double? _fixInterval;
  late double _horizon = predictionHorizon;
  double? _lastFixT;

  /// Effective prediction horizon (s) for the current fix stream.
  double get horizon => _horizon;

  /// Whether at least one valid fix was received.
  bool get hasFix => _t0 != null;

  /// Whether the last fix was stale/invalid (display frozen).
  bool get isStale => _stale;

  /// Current estimated ground velocity (m/s east, north).
  (double, double) get velocity => (_vE, _vN);

  /// Forgets all state; the next fix is shown directly.
  void reset() {
    _t0 = null;
    _ht = null;
    _vE = _vN = _eE = _eN = 0;
    _hA = _hR = _hOff = 0;
    _stale = false;
    _history.clear();
    _fixInterval = null;
    _lastFixT = null;
    _horizon = predictionHorizon;
  }

  /// Adds a fix received at time [t] (seconds, monotonic).
  ///
  /// Set [snap] to force an immediate jump (replay seek, flight load).
  void addFix(MotionFix fix, double t, {bool snap = false}) {
    final displayed = hasFix ? sample(t) : null;

    if (fix.stale) {
      // Freeze at what is currently shown; do not move to the stale fix.
      if (displayed != null) {
        _freezeAt(displayed, t);
      }
      _stale = true;
      _history.clear();
      return;
    }

    var doSnap = snap || displayed == null || _stale;
    if (!doSnap &&
        distanceM(
              displayed.latitude,
              displayed.longitude,
              fix.latitude,
              fix.longitude,
            ) >
            snapDistanceM) {
      doSnap = true;
    }
    final resumedFromStale = _stale;
    _stale = false;

    if (doSnap) {
      _history.clear();
      _fixInterval = null;
      _lastFixT = null;
    }
    _history.add(_HistoryEntry(t, fix.latitude, fix.longitude));
    _estimateVelocity(t);

    if (doSnap || displayed == null) {
      _eE = 0;
      _eN = 0;
    } else {
      final (dE, dN) = _offsetMeters(
        fix.latitude,
        fix.longitude,
        displayed.latitude,
        displayed.longitude,
      );
      _eE = dE;
      _eN = dN;
    }
    _t0 = t;
    _lat0 = fix.latitude;
    _lon0 = fix.longitude;

    _updateHeading(
      fix,
      t,
      snap: (doSnap && !resumedFromStale) || displayed == null,
      displayedHeading: displayed?.headingDeg,
    );
    // Last: the new horizon only applies to the trajectory after this fix.
    _updateFixInterval(t);
  }

  void _updateFixInterval(double t) {
    final last = _lastFixT;
    _lastFixT = t;
    if (last != null) {
      final dt = t - last;
      if (dt > 0.02 && dt <= maxVelocityGap) {
        final prev = _fixInterval;
        _fixInterval = prev == null ? dt : prev + 0.3 * (dt - prev);
      }
    }
    final interval = _fixInterval;
    _horizon = interval == null
        ? predictionHorizon
        : math.min(predictionHorizon, interval * horizonIntervals);
  }

  void _freezeAt(MotionSample s, double t) {
    _t0 = t;
    _lat0 = s.latitude;
    _lon0 = s.longitude;
    _vE = _vN = _eE = _eN = 0;
    if (_ht != null) {
      _hA = _unwrapNear(s.headingDeg, _headingUnwrappedAt(t));
      _hR = 0;
      _hOff = 0;
      _ht = t;
    }
  }

  void _estimateVelocity(double t) {
    // Drop entries too old to contribute.
    while (_history.length > 2 && t - _history[1].t > maxVelocityGap) {
      _history.removeAt(0);
    }
    if (_history.length < 2) {
      _vE = _vN = 0;
      return;
    }
    // Most recent entry at least [velocityBaseline] older than the newest:
    // the previous fix at 1 Hz, a few fixes back for high-rate sources
    // (reduces frame-quantization noise of arrival times). Falls back to the
    // oldest entry.
    final newest = _history.last;
    var ref = _history.first;
    for (var i = _history.length - 2; i >= 0; i--) {
      if (newest.t - _history[i].t >= velocityBaseline) {
        ref = _history[i];
        break;
      }
    }
    final dt = newest.t - ref.t;
    if (dt < 0.05 || dt > maxVelocityGap) {
      _vE = _vN = 0;
      return;
    }
    final (dE, dN) = _offsetMeters(
      ref.latitude,
      ref.longitude,
      newest.latitude,
      newest.longitude,
    );
    var vE = dE / dt;
    var vN = dN / dt;
    final speed = math.sqrt(vE * vE + vN * vN);
    if (speed > maxSpeedMps) {
      vE *= maxSpeedMps / speed;
      vN *= maxSpeedMps / speed;
    }
    _vE = vE;
    _vN = vN;
  }

  void _updateHeading(
    MotionFix fix,
    double t, {
    required bool snap,
    double? displayedHeading,
  }) {
    final m = fix.headingDeg;
    final slow = fix.speedKmh != null && fix.speedKmh! < groundSpeedHoldKmh;
    if (m == null || !m.isFinite || (slow && _ht != null)) {
      // Hold: re-anchor the current display without changing it.
      if (_ht != null) {
        final cur = _headingUnwrappedAt(t);
        _hA = cur;
        _hR = 0;
        _hOff = 0;
        _ht = t;
      }
      return;
    }
    if (_ht == null || snap) {
      _ht = t;
      _hA = m;
      _hR = 0;
      _hOff = 0;
      return;
    }
    final dt = t - _ht!;
    final current = _headingUnwrappedAt(t);
    if (dt <= 1e-3) {
      return;
    }
    if (dt > maxVelocityGap) {
      // Long gap: restart the estimator from the measurement, blend display.
      _hA = _unwrapNear(m, current);
      _hR = 0;
      _hOff = current - _hA;
      _ht = t;
      return;
    }
    final predicted = _hA + _hR * math.min(dt, _horizon);
    final measured = _unwrapNear(m, predicted);
    final residual = measured - predicted;
    final alpha = 1.0 - math.pow(1.0 - headingAlpha, dt).toDouble();
    final beta = headingBeta * math.min(dt, 1.0);
    _hA = predicted + alpha * residual;
    _hR = (_hR + beta * residual / dt).clamp(-maxTurnRateDegS, maxTurnRateDegS);
    _hOff = current - _hA;
    _ht = t;
  }

  double _headingUnwrappedAt(double t) {
    final ht = _ht;
    if (ht == null) return 0;
    final dt = math.max(0.0, t - ht);
    return _hA +
        _hR * math.min(dt, _horizon) +
        _hOff * math.exp(-dt / headingTau);
  }

  /// Displayed state at time [t] (seconds), or null before the first fix.
  MotionSample? sample(double t) {
    final t0 = _t0;
    if (t0 == null) return null;
    final dt = math.max(0.0, t - t0);
    final p = math.min(dt, _horizon);
    final decay = math.exp(-dt / convergenceTau);
    final east = _vE * p + _eE * decay;
    final north = _vN * p + _eN * decay;
    final lat = _lat0 + north / _metersPerDegLat;
    final lon = _lon0 + east / (_metersPerDegLat * _cosLat(_lat0));
    final heading = _ht == null ? 0.0 : normalizeDeg(_headingUnwrappedAt(t));
    return MotionSample(lat, lon, heading);
  }

  /// Whether the output no longer changes after time [t] (no prediction
  /// running and all blends converged), so frame updates can stop.
  bool isSettled(double t) {
    final t0 = _t0;
    if (t0 == null) return true;
    final dt = t - t0;
    final moving = (_vE != 0 || _vN != 0) && dt < _horizon;
    if (moving) return false;
    final decay = math.exp(-math.max(0.0, dt) / convergenceTau);
    if ((_eE.abs() + _eN.abs()) * decay > 0.05) return false;
    final ht = _ht;
    if (ht != null) {
      final hdt = t - ht;
      if (_hR != 0 && hdt < _horizon) return false;
      if (_hOff.abs() * math.exp(-math.max(0.0, hdt) / headingTau) > 0.05) {
        return false;
      }
    }
    return true;
  }

  // --- geometry helpers ---------------------------------------------------

  static double _cosLat(double lat) =>
      math.cos(lat * math.pi / 180.0).abs().clamp(0.01, 1.0);

  /// Local equirectangular offset (m east, m north) from a to b.
  static (double, double) _offsetMeters(
    double latA,
    double lonA,
    double latB,
    double lonB,
  ) {
    final north = (latB - latA) * _metersPerDegLat;
    var dLon = lonB - lonA;
    if (dLon > 180) dLon -= 360;
    if (dLon < -180) dLon += 360;
    final east = dLon * _metersPerDegLat * _cosLat((latA + latB) / 2);
    return (east, north);
  }

  /// Approximate distance in meters (equirectangular, fine below ~100 km).
  static double distanceM(double latA, double lonA, double latB, double lonB) {
    final (e, n) = _offsetMeters(latA, lonA, latB, lonB);
    return math.sqrt(e * e + n * n);
  }

  /// Normalizes [deg] to [0, 360).
  static double normalizeDeg(double deg) {
    final r = deg % 360.0;
    return r < 0 ? r + 360.0 : r;
  }

  /// Shortest signed difference `to - from` in (-180, 180].
  static double shortestDelta(double from, double to) {
    var d = (to - from) % 360.0;
    if (d > 180) d -= 360;
    if (d <= -180) d += 360;
    return d;
  }

  static double _unwrapNear(double angle, double reference) =>
      reference + shortestDelta(reference, angle);
}
