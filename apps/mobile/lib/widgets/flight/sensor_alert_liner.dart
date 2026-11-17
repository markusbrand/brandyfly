import 'package:flutter/material.dart';

import '../../domain/models/sensor_readiness.dart';

/// Persistent top alert liner displayed across the application while required
/// live flight sensors (barometer/vario and GPS) are missing, unpermitted,
/// disconnected, or stale.
///
/// This banner is intentionally non-dismissable and clears automatically once
/// valid required sensor values arrive.
class SensorAlertLiner extends StatelessWidget {
  const SensorAlertLiner({
    super.key,
    required this.state,
    this.onOpenSettings,
  });

  final SensorReadinessState state;
  final VoidCallback? onOpenSettings;

  static const Color _bannerBackground = Color(0xFFB45309);
  static const Color _bannerBorder = Color(0xFFFCD34D);

  @override
  Widget build(BuildContext context) {
    if (!state.shouldShowBanner) {
      return const SizedBox.shrink();
    }

    return Semantics(
      container: true,
      liveRegion: true,
      label: state.warningMessage,
      child: Material(
        key: const Key('sensor_alert_liner'),
        color: _bannerBackground,
        elevation: 4,
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: _bannerBorder, width: 1.5),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.sensors_off_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.warningMessage,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (onOpenSettings != null) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      key: const Key('sensor_alert_liner_settings_btn'),
                      onPressed: onOpenSettings,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.black26,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        minimumSize: const Size(48, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                          side: const BorderSide(color: Colors.white38),
                        ),
                      ),
                      icon: const Icon(Icons.settings, size: 14),
                      label: const Text(
                        'Settings',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
