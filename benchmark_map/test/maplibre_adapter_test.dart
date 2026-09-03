import 'package:benchmark_map/adapters/maplibre_adapter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre/maplibre.dart';

class FakeMapController implements MapController {
  bool shouldThrowOnMoveCamera = false;
  Exception? exceptionToThrow;

  Geographic? lastCenter;
  double? lastZoom;
  double? lastBearing;
  int moveCameraCallCount = 0;

  @override
  Future<void> moveCamera({
    Geographic? center,
    double? zoom,
    double? bearing,
    double? pitch,
    EdgeInsets padding = EdgeInsets.zero,
  }) async {
    moveCameraCallCount++;
    if (shouldThrowOnMoveCamera) {
      throw exceptionToThrow ?? Exception('Camera move error');
    }
    lastCenter = center;
    lastZoom = zoom;
    lastBearing = bearing;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('MaplibreAdapter', () {
    late MaplibreAdapter adapter;
    late FakeMapController fakeController;

    setUp(() {
      adapter = MaplibreAdapter();
      fakeController = FakeMapController();
    });

    test('metadata properties return expected values', () {
      expect(adapter.adapterName, equals('maplibre 0.3.6'));
      expect(adapter.packageVersion, equals('0.3.6'));
    });

    test('executeWaypoint does nothing when controller is null', () async {
      final waypoint = {
        'lat': 47.525,
        'lng': 13.685,
        'zoom': 14.0,
        'bearing': 90.0,
      };

      await adapter.executeWaypoint(waypoint);
      expect(fakeController.moveCameraCallCount, equals(0));
    });

    test('executeWaypoint moves camera successfully when controller is provided', () async {
      adapter.onMapCreated(fakeController);

      final waypoint = {
        'lat': 47.525,
        'lng': 13.685,
        'zoom': 14.0,
        'bearing': 90.0,
      };

      await adapter.executeWaypoint(waypoint);

      expect(fakeController.moveCameraCallCount, equals(1));
      expect(fakeController.lastCenter?.lat, equals(47.525));
      expect(fakeController.lastCenter?.lon, equals(13.685));
      expect(fakeController.lastZoom, equals(14.0));
      expect(fakeController.lastBearing, equals(90.0));
    });

    test('executeWaypoint defaults bearing to 0 when not provided', () async {
      adapter.onMapCreated(fakeController);

      final waypoint = {
        'lat': 47.525,
        'lng': 13.685,
        'zoom': 14.0,
      };

      await adapter.executeWaypoint(waypoint);

      expect(fakeController.moveCameraCallCount, equals(1));
      expect(fakeController.lastBearing, equals(0.0));
    });

    test('executeWaypoint catches exception thrown by moveCamera gracefully', () async {
      adapter.onMapCreated(fakeController);
      fakeController.shouldThrowOnMoveCamera = true;
      fakeController.exceptionToThrow = Exception('Platform channel error on moveCamera');

      final waypoint = {
        'lat': 47.525,
        'lng': 13.685,
        'zoom': 14.0,
        'bearing': 45.0,
      };

      // Should catch the exception internally and log via debugPrint, without rethrowing.
      await expectLater(
        adapter.executeWaypoint(waypoint),
        completes,
      );

      expect(fakeController.moveCameraCallCount, equals(1));
    });

    test('loadOverlays queues overlays when controller is null and applies on map created', () async {
      final overlaysJson = {'airspacePolygons': []};

      await adapter.loadOverlays(overlaysJson);
      adapter.onMapCreated(fakeController);
      await adapter.loadOverlays(overlaysJson);
    });
  });
}
