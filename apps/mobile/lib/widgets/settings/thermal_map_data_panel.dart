import 'package:flutter/material.dart';

import '../../domain/thermal/kk7_provider.dart';
import '../../domain/thermal/thermal_variant.dart';
import '../../services/screen_manager_service.dart';
import '../../services/thermal_prefetch_service.dart';

/// Settings panel listing downloaded map regions with their KK7 thermal
/// prefetch state, a per-region refresh / retry action and the global
/// automatic-prefetch switch.
class ThermalMapDataPanel extends StatelessWidget {
  const ThermalMapDataPanel({
    super.key,
    required this.screenManager,
    required this.service,
  });

  final ScreenManagerService screenManager;

  /// Null on platforms without on-device storage (web).
  final ThermalPrefetchService? service;

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static String describe(RegionThermalState s) {
    switch (s.status) {
      case ThermalPrefetchStatus.notPrefetched:
        return 'Not downloaded';
      case ThermalPrefetchStatus.inProgress:
        return 'Downloading… ${s.percent} %';
      case ThermalPrefetchStatus.complete:
        final seasons = s.completeSeasons.map((e) => e.label).join(', ');
        return 'Complete · ${formatBytes(s.bytes)}'
            '${seasons.isEmpty ? '' : ' · $seasons'}';
      case ThermalPrefetchStatus.partial:
        return 'Partial (${s.percent} %) · ${formatBytes(s.bytes)}'
            '${s.lastError == null ? '' : ' · ${s.lastError}'}';
      case ThermalPrefetchStatus.failed:
        return 'Failed${s.lastError == null ? '' : ' · ${s.lastError}'}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final svc = service;
    return Card(
      key: const Key('thermal_map_data_panel'),
      color: Colors.grey.shade900,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Thermal Map Data (offline)',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            AnimatedBuilder(
              animation: screenManager,
              builder: (context, _) => SwitchListTile(
                key: const Key('thermal_auto_prefetch_switch'),
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Auto-download for map regions',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                subtitle: const Text(
                  'Current and upcoming season, all times of day',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
                value: screenManager.config.thermalAutoPrefetch,
                activeThumbColor: Colors.cyanAccent,
                onChanged: (val) {
                  screenManager.setThermalAutoPrefetch(val);
                  if (val) svc?.runAutomatic();
                },
              ),
            ),
            const Divider(color: Colors.white12),
            if (svc == null)
              const Text(
                'Thermal map prefetch is not available on this platform.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              )
            else
              ListenableBuilder(
                listenable: svc,
                builder: (context, _) {
                  final states = svc.states.values.toList()
                    ..sort((a, b) => a.regionId.compareTo(b.regionId));
                  if (states.isEmpty) {
                    return const Text(
                      'No offline map regions downloaded yet.',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    );
                  }
                  return Column(
                    children: [for (final s in states) _regionTile(svc, s)],
                  );
                },
              ),
            const SizedBox(height: 4),
            const Text(
              Kk7Provider.attributionText,
              style: TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _regionTile(ThermalPrefetchService svc, RegionThermalState s) {
    final busy = s.status == ThermalPrefetchStatus.inProgress;
    final retry =
        s.status == ThermalPrefetchStatus.failed ||
        s.status == ThermalPrefetchStatus.partial;
    return Column(
      key: Key('thermal_region_${s.regionId}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(
            s.regionId,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          subtitle: Text(
            describe(s),
            style: TextStyle(
              color: s.status == ThermalPrefetchStatus.failed
                  ? Colors.redAccent
                  : Colors.white54,
              fontSize: 11,
            ),
          ),
          trailing: IconButton(
            key: Key('thermal_retry_${s.regionId}'),
            tooltip: retry ? 'Retry thermal download' : 'Refresh thermal data',
            icon: Icon(
              retry ? Icons.replay : Icons.download_for_offline_outlined,
              color: busy ? Colors.white24 : Colors.cyanAccent,
            ),
            onPressed: busy ? null : () => svc.prefetchRegion(s.regionId),
          ),
        ),
        if (busy)
          LinearProgressIndicator(
            value: s.progress,
            minHeight: 3,
            color: Colors.cyanAccent,
            backgroundColor: Colors.white12,
          ),
      ],
    );
  }
}
