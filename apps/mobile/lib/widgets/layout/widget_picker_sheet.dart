import 'package:flutter/material.dart';
import '../../models/ui_config.dart';
import '../../services/screen_manager_service.dart';

class WidgetPickerSheet extends StatelessWidget {
  const WidgetPickerSheet({
    super.key,
    required this.screenManager,
  });

  final ScreenManagerService screenManager;

  @override
  Widget build(BuildContext context) {
    final available = [
      (WidgetType.altitude, 'Altitude', 'Displays current MSL altitude', Icons.height),
      (WidgetType.speed, 'Groundspeed', 'Displays speed over ground', Icons.speed),
      (WidgetType.glide, 'Glide Ratio', 'Displays L/D glide ratio', Icons.trending_flat),
      (WidgetType.hag, 'Height Above Ground', 'Displays AGL height', Icons.vertical_align_bottom),
      (WidgetType.windDirection, 'Wind Indicator', 'Displays wind direction & speed', Icons.air),
      (WidgetType.varioBar, 'Vario Lift/Sink', 'Visual climb and sink indicator', Icons.straighten),
      (WidgetType.altitudeChart, 'Altitude Chart', 'Sparkline height history chart', Icons.show_chart),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Add Flight Widget',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: available.length,
              separatorBuilder: (context, index) => const Divider(color: Colors.white12),
              itemBuilder: (ctx, index) {
                final item = available[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blueAccent.withAlpha(40),
                    child: Icon(item.$4, color: Colors.blueAccent),
                  ),
                  title: Text(
                    item.$2,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    item.$3,
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                    ),
                    onPressed: () {
                      screenManager.addWidget(item.$1);
                      Navigator.pop(context);
                    },
                    child: const Text('Add'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
