import 'package:flutter/material.dart';

import '../../models/region_models.dart';
import '../../services/region_manager_service.dart';

/// Screen allowing pilots to browse, download, update, and delete
/// offline map and DEM regions curated by flying areas.
class RegionManagerScreen extends StatefulWidget {
  const RegionManagerScreen({
    super.key,
    required this.regionManager,
    this.onRegionDownloaded,
  });

  final RegionManagerService regionManager;
  final ValueChanged<String>? onRegionDownloaded;

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  State<RegionManagerScreen> createState() => _RegionManagerScreenState();
}

class _RegionManagerScreenState extends State<RegionManagerScreen> {
  RegionManagerService get _rm => widget.regionManager;

  bool _isLoading = false;
  String? _errorMessage;
  List<DownloadedRegion> _downloaded = [];
  StorageUsage _storageUsage = StorageUsage.zero;

  @override
  void initState() {
    super.initState();
    _rm.addListener(_onServiceChanged);
    _loadData();
  }

  @override
  void dispose() {
    _rm.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) {
      _refreshLocalData();
    }
  }

  Future<void> _refreshLocalData() async {
    final downloaded = await _rm.getDownloadedRegions();
    final storage = await _rm.getStorageUsage();
    if (mounted) {
      setState(() {
        _downloaded = downloaded;
        _storageUsage = storage;
      });
    }
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _rm.fetchCatalog(forceRefresh: forceRefresh);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      if (mounted) {
        await _refreshLocalData();
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _startDownload(String regionId) async {
    final stream = _rm.downloadRegion(regionId);
    final lastProgress = await stream.last;
    if (lastProgress.status == DownloadStatus.completed) {
      widget.onRegionDownloaded?.call(regionId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Region $regionId downloaded successfully.'),
            backgroundColor: Colors.green.shade800,
          ),
        );
      }
    } else if (lastProgress.status == DownloadStatus.failed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Download failed: ${lastProgress.errorMessage ?? 'Unknown error'}',
            ),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete(String regionId, String regionName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: Text('Delete $regionName?'),
        content: Text(
          'This will remove all downloaded vector map and terrain DEM files for $regionName from this device.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _rm.deleteRegion(regionId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$regionName deleted.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = _rm.catalog;
    final downloadedMap = {for (final d in _downloaded) d.id: d};

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Offline Map Regions'),
        backgroundColor: Colors.grey.shade900,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh catalog',
            onPressed: () => _loadData(forceRefresh: true),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadData(forceRefresh: true),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _buildStorageHeader(),
            ),
            if (catalog == null && !_isLoading)
              SliverToBoxAdapter(
                child: _buildOfflineBanner(),
              ),
            if (_isLoading && catalog == null)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final regions = catalog?.regions ?? const [];
                      if (index < regions.length) {
                        final entry = regions[index];
                        final local = downloadedMap[entry.id];
                        final progress = _rm.getProgress(entry.id);
                        final isUpdating = local != null &&
                            entry.version != local.version;
                        return _buildRegionCard(
                          entry: entry,
                          downloaded: local,
                          progress: progress,
                          isUpdateAvailable: isUpdating,
                        );
                      }

                      // Check if there are any downloaded regions not in the catalog
                      final extraDownloaded = _downloaded
                          .where((d) =>
                              catalog == null ||
                              catalog.findRegion(d.id) == null)
                          .toList();

                      final extraIndex = index - regions.length;
                      if (extraIndex >= 0 && extraIndex < extraDownloaded.length) {
                        final local = extraDownloaded[extraIndex];
                        return _buildLegacyRegionCard(local);
                      }

                      return null;
                    },
                    childCount: (catalog?.regions.length ?? 0) +
                        _downloaded
                            .where((d) =>
                                catalog == null ||
                                catalog.findRegion(d.id) == null)
                            .length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Offline Maps Storage',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                RegionManagerScreen.formatBytes(_storageUsage.totalBytes),
                style: const TextStyle(
                  color: Colors.lightBlueAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _storageUsage.totalBytes > 0 ? 1.0 : 0.0,
              minHeight: 8,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.lightBlueAccent),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_downloaded.length} regions stored locally for offline flying.',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.shade900.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade700),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, color: Colors.amberAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage != null
                  ? 'Offline or network error: $_errorMessage'
                  : 'Internet connection required to browse or refresh available map regions.',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: () => _loadData(forceRefresh: true),
            child: const Text('Retry', style: TextStyle(color: Colors.amberAccent)),
          ),
        ],
      ),
    );
  }

  Widget _buildRegionCard({
    required RegionEntry entry,
    required DownloadedRegion? downloaded,
    required RegionDownloadProgress? progress,
    required bool isUpdateAvailable,
  }) {
    final isDownloading = progress != null &&
        (progress.status == DownloadStatus.downloading ||
            progress.status == DownloadStatus.verifying);

    return Card(
      key: Key('region_card_${entry.id}'),
      color: Colors.grey.shade900,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isUpdateAvailable ? Colors.amber.shade700 : Colors.white12,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.description,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusBadge(
                  isDownloaded: downloaded != null,
                  isUpdateAvailable: isUpdateAvailable,
                  isDownloading: isDownloading,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Size: ${RegionManagerScreen.formatBytes(entry.totalSizeBytes)}',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const SizedBox(width: 16),
                Text(
                  'Version: ${entry.version}',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
            if (isDownloading) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: progress.progress,
                minHeight: 6,
                backgroundColor: Colors.white10,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    progress.status == DownloadStatus.verifying
                        ? 'Verifying checksums…'
                        : 'Downloading ${progress.currentFile ?? ''}… ${progress.percent}%',
                    style: const TextStyle(color: Colors.greenAccent, fontSize: 12),
                  ),
                  Text(
                    '${RegionManagerScreen.formatBytes(progress.bytesDownloaded)} / ${RegionManagerScreen.formatBytes(progress.totalBytes)}',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (downloaded != null) ...[
                  OutlinedButton.icon(
                    key: Key('delete_button_${entry.id}'),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                    ),
                    onPressed: isDownloading
                        ? null
                        : () => _confirmDelete(entry.id, entry.name),
                  ),
                  const SizedBox(width: 8),
                ],
                if (isUpdateAvailable)
                  FilledButton.icon(
                    key: Key('update_button_${entry.id}'),
                    icon: const Icon(Icons.update, size: 18),
                    label: const Text('Update'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                    ),
                    onPressed: isDownloading ? null : () => _startDownload(entry.id),
                  )
                else if (downloaded == null)
                  FilledButton.icon(
                    key: Key('download_button_${entry.id}'),
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Download'),
                    onPressed: isDownloading ? null : () => _startDownload(entry.id),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegacyRegionCard(DownloadedRegion local) {
    return Card(
      key: Key('legacy_region_card_${local.id}'),
      color: Colors.grey.shade900,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    local.id,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                _buildStatusBadge(
                  isDownloaded: true,
                  isUpdateAvailable: false,
                  isDownloading: false,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Local storage: ${RegionManagerScreen.formatBytes(local.sizeBytes)}',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Delete'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                ),
                onPressed: () => _confirmDelete(local.id, local.id),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge({
    required bool isDownloaded,
    required bool isUpdateAvailable,
    required bool isDownloading,
  }) {
    if (isDownloading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.blue.shade900.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.blueAccent),
        ),
        child: const Text(
          'Downloading',
          style: TextStyle(color: Colors.lightBlueAccent, fontSize: 11),
        ),
      );
    }

    if (isUpdateAvailable) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.amber.shade900.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.amberAccent),
        ),
        child: const Text(
          'Update available',
          style: TextStyle(color: Colors.amberAccent, fontSize: 11),
        ),
      );
    }

    if (isDownloaded) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.shade900.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.greenAccent),
        ),
        child: const Text(
          'Downloaded',
          style: TextStyle(color: Colors.greenAccent, fontSize: 11),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white24),
      ),
      child: const Text(
        'Available',
        style: TextStyle(color: Colors.white70, fontSize: 11),
      ),
    );
  }
}
