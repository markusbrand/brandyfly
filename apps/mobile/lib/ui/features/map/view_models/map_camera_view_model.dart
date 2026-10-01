import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Camera state of one map widget instance: zoom (with limits), center-lock
/// and the inactivity auto-recenter timer.
///
/// Both the map's built-in HUD buttons and placeable map control widgets call
/// the same commands, so their behavior is identical by construction.
class MapCameraViewModel extends ChangeNotifier {
  MapCameraViewModel({
    double initialZoom = 13.5,
    this.minZoom = 1.0,
    this.maxZoom = 22.0,
    this.zoomStep = 0.5,
    this.recenterDelay = const Duration(seconds: 6),
  }) : _zoom = initialZoom.clamp(minZoom, maxZoom);

  final double minZoom;
  final double maxZoom;
  final double zoomStep;
  final Duration recenterDelay;

  double _zoom;
  bool _centerLocked = true;
  int _recenterRequests = 0;
  Timer? _recenterTimer;
  bool _disposed = false;

  double get zoom => _zoom;
  bool get centerLocked => _centerLocked;
  bool get canZoomIn => _zoom < maxZoom - 1e-9;
  bool get canZoomOut => _zoom > minZoom + 1e-9;
  bool get isDisposed => _disposed;

  /// Incremented on every recenter (manual or timer); the map widget animates
  /// back to the pilot when it changes.
  int get recenterRequests => _recenterRequests;

  /// True while the auto-recenter timer is pending.
  bool get recenterPending => _recenterTimer?.isActive ?? false;

  void zoomIn() => zoomBy(zoomStep);
  void zoomOut() => zoomBy(-zoomStep);

  /// Changes zoom by [delta] within limits. During a temporary pan the
  /// inactivity timer is restarted.
  void zoomBy(double delta) {
    if (_disposed) return;
    final next = (_zoom + delta).clamp(minZoom, maxZoom);
    if (next == _zoom) return;
    _zoom = next;
    if (!_centerLocked) _restartTimer();
    notifyListeners();
  }

  /// Cancels the inactivity timer and restores center-locked tracking.
  void recenter() {
    if (_disposed) return;
    _recenterTimer?.cancel();
    _recenterTimer = null;
    _centerLocked = true;
    _recenterRequests++;
    notifyListeners();
  }

  /// Called when the pilot pans the map: releases center-lock and (re)starts
  /// the inactivity timer.
  void beginManualPan() {
    if (_disposed) return;
    _restartTimer();
    if (_centerLocked) {
      _centerLocked = false;
      notifyListeners();
    }
  }

  /// Syncs zoom reported by a native gesture without re-issuing a camera move.
  void syncZoomFromGesture(double zoom) {
    if (_disposed) return;
    final next = zoom.clamp(minZoom, maxZoom);
    if (next == _zoom) return;
    _zoom = next;
    notifyListeners();
  }

  /// Resets zoom (e.g. configured initial zoom changed) without notifying.
  void resetZoom(double zoom) {
    _zoom = zoom.clamp(minZoom, maxZoom);
  }

  void _restartTimer() {
    _recenterTimer?.cancel();
    _recenterTimer = Timer(recenterDelay, recenter);
  }

  @override
  void dispose() {
    _disposed = true;
    _recenterTimer?.cancel();
    _recenterTimer = null;
    super.dispose();
  }
}

/// Registry of map camera view models on one flight canvas, keyed by map
/// widget placement id. Map control widgets look up their target here.
class MapCameraRegistry extends ChangeNotifier {
  final Map<String, MapCameraViewModel> _cameras = {};
  bool _notifyScheduled = false;
  bool _disposed = false;

  MapCameraViewModel? lookup(String? id) => id == null ? null : _cameras[id];

  Iterable<String> get registeredIds => _cameras.keys;

  void register(String id, MapCameraViewModel camera) {
    if (identical(_cameras[id], camera)) return;
    _cameras[id] = camera;
    _scheduleNotify();
  }

  void unregister(String id, MapCameraViewModel camera) {
    if (!identical(_cameras[id], camera)) return;
    _cameras.remove(id);
    _scheduleNotify();
  }

  /// Registration happens during build/mount; defer notification to after the
  /// frame so listeners never call setState during build.
  void _scheduleNotify() {
    if (_notifyScheduled || _disposed) return;
    _notifyScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _notifyScheduled = false;
      if (!_disposed) notifyListeners();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    _disposed = true;
    _cameras.clear();
    super.dispose();
  }
}

/// Provides a [MapCameraRegistry] to map widgets and map control widgets of a
/// flight canvas.
class MapCameraScope extends InheritedWidget {
  const MapCameraScope({
    super.key,
    required this.registry,
    required super.child,
  });

  final MapCameraRegistry registry;

  /// Registry of the nearest scope, without creating a rebuild dependency.
  static MapCameraRegistry? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<MapCameraScope>()?.registry;

  @override
  bool updateShouldNotify(MapCameraScope oldWidget) =>
      !identical(oldWidget.registry, registry);
}
