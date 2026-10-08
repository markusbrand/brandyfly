import 'package:flutter/material.dart';

import '../../models/region_models.dart';
import '../../services/region_manager_service.dart';
import 'region_manager_screen.dart';

/// Pre-flight bottom sheet prompt shown when the pilot is outside
/// downloaded map regions.
class PreFlightCoveragePrompt extends StatefulWidget {
  const PreFlightCoveragePrompt({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.regionManager,
    this.onDismiss,
    this.onManageRegions,
  });

  final double latitude;
  final double longitude;
  final RegionManagerService regionManager;
  final VoidCallback? onDismiss;
  final VoidCallback? onManageRegions;

  /// Helper to display this prompt as a modal bottom sheet.
  static Future<void> show({
    required BuildContext context,
    required double latitude,
    required double longitude,
    required RegionManagerService regionManager,
    VoidCallback? onManageRegions,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PreFlightCoveragePrompt(
        latitude: latitude,
        longitude: longitude,
        regionManager: regionManager,
        onDismiss: () => Navigator.of(ctx).pop(),
        onManageRegions: () {
          Navigator.of(ctx).pop();
          if (onManageRegions != null) {
            onManageRegions();
          } else {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    RegionManagerScreen(regionManager: regionManager),
              ),
            );
          }
        },
      ),
    );
  }

  @override
  State<PreFlightCoveragePrompt> createState() =>
      _PreFlightCoveragePromptState();
}

class _PreFlightCoveragePromptState extends State<PreFlightCoveragePrompt> {
  RegionManagerService get _rm => widget.regionManager;

  @override
  Widget build(BuildContext context) {
    final suggested = _rm.getSuggestedRegions(
      widget.latitude,
      widget.longitude,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                const Icon(
                  Icons.map_outlined,
                  color: Colors.amberAccent,
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'No Offline Map Coverage',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  tooltip: 'Dismiss',
                  onPressed: _handleDismiss,
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Your GPS location is outside any downloaded map regions. Download map coverage before leaving cell connectivity for offline in-flight navigation.',
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            if (suggested.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No matching regions found in the catalog.',
                  style: TextStyle(color: Colors.white60, fontSize: 13),
                ),
              )
            else
              ...suggested.map((entry) => _buildSuggestedItem(entry)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _handleDismiss,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                    ),
                    child: const Text('Not Now'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: widget.onManageRegions,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                    ),
                    child: const Text('Manage Regions'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestedItem(RegionEntry entry) {
    final progress = _rm.getProgress(entry.id);
    final isDownloading = progress != null &&
        (progress.status == DownloadStatus.downloading ||
            progress.status == DownloadStatus.verifying);
    final isCompleted = progress?.status == DownloadStatus.completed;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${entry.description} · ${RegionManagerScreen.formatBytes(entry.totalSizeBytes)}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isCompleted)
                const Icon(Icons.check_circle, color: Colors.greenAccent, size: 24)
              else
                FilledButton.tonalIcon(
                  onPressed: isDownloading
                      ? null
                      : () => _rm.downloadRegion(entry.id),
                  icon: isDownloading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download, size: 16),
                  label: Text(isDownloading ? '${progress.percent}%' : 'Download'),
                ),
            ],
          ),
          if (isDownloading) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress.progress,
              minHeight: 4,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
            ),
          ],
        ],
      ),
    );
  }

  void _handleDismiss() {
    _rm.dismissPromptForSession(widget.latitude, widget.longitude);
    widget.onDismiss?.call();
  }
}
