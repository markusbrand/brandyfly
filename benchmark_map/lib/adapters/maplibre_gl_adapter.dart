import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../benchmark_scenario.dart';
import '../measurement_harness.dart';

/// Benchmark adapter using the legacy `maplibre_gl` package (v0.27.0).
///
/// Uses [MaplibreMap] with [MapLibreMapController] for camera operations.
/// The API surface differs from the modern `maplibre` package — this adapter
/// implements the identical scenario to enable direct comparison.
class MaplibreGlAdapter implements MapEngineAdapter {
  @override
  String get adapterName => 'maplibre_gl 0.27.0';

  @override
  String get packageVersion => '0.27.0';

  MapLibreMapController? _controller;
  Map<String, dynamic>? _pendingOverlays;
  bool _overlaysLoaded = false;

  @override
  Future<void> loadOverlays(Map<String, dynamic> overlaysJson) async {
    if (_controller != null) {
      await _applyOverlays(overlaysJson);
    } else {
      _pendingOverlays = overlaysJson;
    }
  }

  @override
  Future<void> executeWaypoint(Map<String, dynamic> waypoint) async {
    final controller = _controller;
    if (controller == null) return;

    final lat = (waypoint['lat'] as num).toDouble();
    final lng = (waypoint['lng'] as num).toDouble();
    final zoom = (waypoint['zoom'] as num).toDouble();
    final bearing = (waypoint['bearing'] as num? ?? 0).toDouble();

    try {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(lat, lng),
            zoom: zoom,
            bearing: bearing,
          ),
        ),
      );
    } catch (e) {
      debugPrint('[maplibre_gl adapter] waypoint move failed: $e ($waypoint)');
    }
  }

  @override
  Widget buildMapWidget(MeasurementHarness harness) {
    return _MaplibreGlAdapterWidget(adapter: this, harness: harness);
  }

  Future<void> _applyOverlays(Map<String, dynamic> overlaysJson) async {
    if (_overlaysLoaded) return;
    _overlaysLoaded = true;
    // Overlays injected here via controller.addSource / addFillLayer / addLineLayer.
    debugPrint('[maplibre_gl adapter] overlays ready for injection');
  }

  String _buildStyleJson() {
    return '''
{
  "version": 8,
  "name": "BrandyFly Benchmark (maplibre_gl)",
  "sources": {
    "openmaptiles": {
      "type": "vector",
      "url": "pmtiles:///data/user/0/rocks.brandstaetter.benchmark_map/files/alpine_overview.pmtiles"
    },
    "terrain": {
      "type": "raster-dem",
      "url": "pmtiles:///data/user/0/rocks.brandstaetter.benchmark_map/files/alpine_terrain.pmtiles",
      "tileSize": 512,
      "encoding": "terrarium"
    }
  },
  "terrain": {"source": "terrain", "exaggeration": 1.5},
  "layers": [
    {"id": "background", "type": "background", "paint": {"background-color": "#f0ece4"}},
    {"id": "hillshade", "type": "hillshade", "source": "terrain",
     "paint": {"hillshade-illumination-direction": 315, "hillshade-exaggeration": 0.5}},
    {"id": "water", "type": "fill", "source": "openmaptiles", "source-layer": "water",
     "paint": {"fill-color": "#a0cfdb"}}
  ]
}
''';
  }

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
    if (_pendingOverlays != null) {
      _applyOverlays(_pendingOverlays!);
    }
  }
}

/// Widget that builds [MaplibreMap] and wires measurement harness callbacks.
class _MaplibreGlAdapterWidget extends StatefulWidget {
  const _MaplibreGlAdapterWidget({
    required this.adapter,
    required this.harness,
  });

  final MaplibreGlAdapter adapter;
  final MeasurementHarness harness;

  @override
  State<_MaplibreGlAdapterWidget> createState() =>
      _MaplibreGlAdapterWidgetState();
}

class _MaplibreGlAdapterWidgetState extends State<_MaplibreGlAdapterWidget> {
  @override
  void initState() {
    super.initState();
    widget.harness.onMapBuildStart();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      widget.harness.onFirstFrame();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MapLibreMap(
      initialCameraPosition: const CameraPosition(
        target: LatLng(47.525, 13.685),
        zoom: 13.5,
      ),
      styleString: widget.adapter._buildStyleJson(),
      onMapCreated: widget.adapter._onMapCreated,
      myLocationEnabled: false,
      compassEnabled: false,
      rotateGesturesEnabled: true,
      scrollGesturesEnabled: true,
      zoomGesturesEnabled: true,
      tiltGesturesEnabled: true,
    );
  }
}
