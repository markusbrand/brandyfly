import 'package:flutter/material.dart';

import '../../../../domain/models/ui_config.dart';
import '../../../../services/screen_manager_service.dart';
import '../../../core/theme/cockpit_tokens.dart';

class _PickerEntry {
  const _PickerEntry(this.type, this.title, this.description, this.icon);
  final WidgetType type;
  final String title;
  final String description;
  final IconData icon;
}

const List<_PickerEntry> _instrumentEntries = [
  _PickerEntry(
    WidgetType.altitude,
    'Altitude',
    'Displays current MSL altitude',
    Icons.height,
  ),
  _PickerEntry(
    WidgetType.speed,
    'Groundspeed',
    'Displays speed over ground',
    Icons.speed,
  ),
  _PickerEntry(
    WidgetType.glide,
    'Glide Ratio',
    'Displays L/D glide ratio',
    Icons.trending_flat,
  ),
  _PickerEntry(
    WidgetType.hag,
    'Height Above Ground',
    'Displays AGL height',
    Icons.vertical_align_bottom,
  ),
  _PickerEntry(
    WidgetType.windDirection,
    'Wind Indicator',
    'Displays wind direction & speed',
    Icons.air,
  ),
  _PickerEntry(
    WidgetType.varioBar,
    'Vario Lift/Sink',
    'Visual climb and sink indicator',
    Icons.straighten,
  ),
  _PickerEntry(
    WidgetType.altitudeChart,
    'Altitude Chart',
    'Sparkline height history chart',
    Icons.show_chart,
  ),
  _PickerEntry(
    WidgetType.map,
    'Offline Map & Terrain',
    'Alpine map with contours, airspace, thermals & track',
    Icons.map,
  ),
  _PickerEntry(
    WidgetType.thermalMap,
    'Thermal Assistant Map',
    'Lift (green) & sink (red) trail with core tracking & ribbon modes',
    Icons.radar,
  ),
  _PickerEntry(
    WidgetType.airspaceSideCut,
    'Airspace Side-Cut Profile',
    'Vertical cross-section of forward airspaces, glide slope & terrain',
    Icons.view_agenda,
  ),
];

const List<_PickerEntry> _mapControlEntries = [
  _PickerEntry(
    WidgetType.mapZoomRocker,
    'Map Zoom Rocker',
    'Zoom in and out in one control',
    Icons.unfold_more,
  ),
  _PickerEntry(
    WidgetType.mapZoomIn,
    'Map Zoom In',
    'Zooms the target map in',
    Icons.zoom_in,
  ),
  _PickerEntry(
    WidgetType.mapZoomOut,
    'Map Zoom Out',
    'Zooms the target map out',
    Icons.zoom_out,
  ),
  _PickerEntry(
    WidgetType.mapRecenter,
    'Map Recenter',
    'Returns the target map to the pilot',
    Icons.my_location,
  ),
];

/// Bottom sheet listing all placeable widgets, grouped into instruments and
/// map controls.
class WidgetPickerSheet extends StatelessWidget {
  const WidgetPickerSheet({super.key, required this.screenManager});

  final ScreenManagerService screenManager;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      const _SectionHeader('Instruments & maps'),
      for (final e in _instrumentEntries) _tile(context, e),
      const _SectionHeader('Map controls'),
      for (final e in _mapControlEntries) _tile(context, e),
    ];

    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Add Flight Widget',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              // Short, fixed list: build it eagerly so every entry is
              // reachable by accessibility services and tests.
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: items,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, _PickerEntry item) {
    return ListTile(
      key: Key('picker_item_${item.type.name}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: CircleAvatar(
        backgroundColor: CockpitTokens.glassCyan.withAlpha(40),
        child: Icon(item.icon, color: CockpitTokens.glassCyan),
      ),
      title: Text(
        item.title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(
        item.description,
        style: const TextStyle(color: Colors.white60, fontSize: 12),
      ),
      trailing: ElevatedButton(
        key: Key('btn_picker_add_${item.type.name}'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent,
          minimumSize: const Size(64, 48),
        ),
        onPressed: () {
          final id = screenManager.addWidget(item.type);
          screenManager.selectWidget(id);
          Navigator.pop(context);
        },
        child: const Text('Add'),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4, left: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: CockpitTokens.glassCyan,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
