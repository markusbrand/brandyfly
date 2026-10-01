import 'package:flutter/material.dart';

import '../../../../domain/models/size_tier.dart';
import '../../../../domain/models/ui_config.dart';
import '../../../core/bezel_button.dart';
import '../../../core/theme/cockpit_tokens.dart';
import '../view_models/map_camera_view_model.dart';

/// Placeable map control (zoom in, zoom out, zoom rocker or recenter) that
/// drives the camera of the map widget with id [targetMapId].
///
/// When no target is available (no map on the variant, missing explicit
/// target, or the map is not mounted) the control renders dimmed and ignores
/// presses.
class MapControlWidget extends StatelessWidget {
  const MapControlWidget({
    super.key,
    required this.placementId,
    required this.type,
    required this.targetMapId,
  }) : assert(
         type == WidgetType.mapZoomIn ||
             type == WidgetType.mapZoomOut ||
             type == WidgetType.mapZoomRocker ||
             type == WidgetType.mapRecenter,
       );

  final String placementId;
  final WidgetType type;

  /// Resolved target map placement id (null = no map).
  final String? targetMapId;

  @override
  Widget build(BuildContext context) {
    final registry = MapCameraScope.maybeOf(context);
    if (registry == null) {
      return _buildControl(context, null);
    }
    return ListenableBuilder(
      listenable: registry,
      builder: (context, _) {
        final camera = registry.lookup(targetMapId);
        if (camera == null) return _buildControl(context, null);
        return ListenableBuilder(
          listenable: camera,
          builder: (context, _) => _buildControl(context, camera),
        );
      },
    );
  }

  Widget _buildControl(BuildContext context, MapCameraViewModel? camera) {
    switch (type) {
      case WidgetType.mapZoomIn:
        return BezelButton(
          key: Key('map_control_zoom_in_$placementId'),
          icon: Icons.add,
          semanticLabel: camera == null ? 'Zoom in (no map)' : 'Zoom in',
          tooltip: 'Zoom in',
          onPressed: camera != null && camera.canZoomIn ? camera.zoomIn : null,
        );
      case WidgetType.mapZoomOut:
        return BezelButton(
          key: Key('map_control_zoom_out_$placementId'),
          icon: Icons.remove,
          semanticLabel: camera == null ? 'Zoom out (no map)' : 'Zoom out',
          tooltip: 'Zoom out',
          onPressed: camera != null && camera.canZoomOut
              ? camera.zoomOut
              : null,
        );
      case WidgetType.mapRecenter:
        return BezelButton(
          key: Key('map_control_recenter_$placementId'),
          icon: Icons.my_location,
          semanticLabel: camera == null
              ? 'Recenter (no map)'
              : camera.centerLocked
              ? 'Recenter, following pilot'
              : 'Recenter on pilot',
          tooltip: 'Center pilot',
          lit: camera?.centerLocked ?? false,
          onPressed: camera?.recenter,
        );
      case WidgetType.mapZoomRocker:
        return _ZoomRocker(placementId: placementId, camera: camera);
      default:
        return const SizedBox.shrink();
    }
  }
}

class _ZoomRocker extends StatelessWidget {
  const _ZoomRocker({required this.placementId, required this.camera});

  final String placementId;
  final MapCameraViewModel? camera;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final vertical = !(w > h);
        final tier = sizeTierFor(w, h);
        final cam = camera;

        final zoomIn = Expanded(
          child: BezelButton(
            key: Key('map_control_rocker_in_$placementId'),
            icon: Icons.add,
            semanticLabel: cam == null ? 'Zoom in (no map)' : 'Zoom in',
            tooltip: 'Zoom in',
            onPressed: cam != null && cam.canZoomIn ? cam.zoomIn : null,
          ),
        );
        final zoomOut = Expanded(
          child: BezelButton(
            key: Key('map_control_rocker_out_$placementId'),
            icon: Icons.remove,
            semanticLabel: cam == null ? 'Zoom out (no map)' : 'Zoom out',
            tooltip: 'Zoom out',
            onPressed: cam != null && cam.canZoomOut ? cam.zoomOut : null,
          ),
        );

        final showReadout = tier == SizeTier.regular && cam != null;
        final readout = showReadout
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                child: Text(
                  'z${cam.zoom.toStringAsFixed(1)}',
                  key: Key('map_control_rocker_zoom_$placementId'),
                  style: CockpitTokens.instrumentLabel.copyWith(
                    fontSize: 11,
                    color: CockpitTokens.glassCyan,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                ),
              )
            : const SizedBox(width: 2, height: 2);

        return vertical
            ? Column(children: [zoomIn, readout, zoomOut])
            : Row(children: [zoomOut, readout, zoomIn]);
      },
    );
  }
}
