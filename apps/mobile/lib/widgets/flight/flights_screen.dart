import 'package:flutter/material.dart';
import '../../models/flight_model.dart';
import '../../services/flight_storage_service.dart';
import '../../services/xcontest_upload_service.dart';

class FlightsScreen extends StatefulWidget {
  const FlightsScreen({
    super.key,
    required this.storageService,
    required this.uploadService,
    required this.onStartReplay,
    required this.onClose,
  });

  final FlightStorageService storageService;
  final XContestUploadService uploadService;
  final void Function(FlightModel flight) onStartReplay;
  final VoidCallback onClose;

  @override
  State<FlightsScreen> createState() => _FlightsScreenState();
}

class _FlightsScreenState extends State<FlightsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.storageService, widget.uploadService]),
      builder: (context, _) {
        final myFlights = widget.storageService.searchFlights(
          _searchQuery,
          category: FlightCategory.myFlights,
        );
        final plannedFlights = widget.storageService.searchFlights(
          _searchQuery,
          category: FlightCategory.plannedFlights,
        );

        return Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1E293B),
            title: const Text('Flights & Logbook'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back to Instrument',
              onPressed: widget.onClose,
            ),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                tooltip: 'More Options',
                onSelected: (val) {
                  if (val == 'import') {
                    _showImportDialog(context);
                  } else if (val == 'restore_sample') {
                    widget.storageService.restoreSampleFlight();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sample flight restored!')),
                    );
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'import',
                    child: ListTile(
                      leading: Icon(Icons.file_upload),
                      title: Text('Import Flight (IGC/JSON)'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'restore_sample',
                    child: ListTile(
                      leading: Icon(Icons.restore),
                      title: Text('Restore Sample Flight'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.cyanAccent,
              labelColor: Colors.cyanAccent,
              unselectedLabelColor: Colors.white60,
              tabs: [
                Tab(
                  icon: const Icon(Icons.flight_takeoff),
                  text: 'My Flights (${myFlights.length})',
                ),
                Tab(
                  icon: const Icon(Icons.map_outlined),
                  text: 'Planned (${plannedFlights.length})',
                ),
              ],
            ),
          ),
          body: Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search by title, pilot, site, date...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white54),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              // Tab views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildFlightList(context, myFlights, isPlanned: false),
                    _buildFlightList(context, plannedFlights, isPlanned: true),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFlightList(
    BuildContext context,
    List<FlightModel> flights, {
    required bool isPlanned,
  }) {
    if (flights.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPlanned ? Icons.route_outlined : Icons.flight_outlined,
              size: 48,
              color: Colors.white24,
            ),
            const SizedBox(height: 12),
            Text(
              isPlanned ? 'No planned flights' : 'No recorded flights yet',
              style: const TextStyle(color: Colors.white60, fontSize: 16),
            ),
            const SizedBox(height: 8),
            if (!isPlanned)
              TextButton.icon(
                icon: const Icon(Icons.restore),
                label: const Text('Restore Sample Flight'),
                onPressed: () => widget.storageService.restoreSampleFlight(),
              ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: flights.length,
      itemBuilder: (context, index) {
        final flight = flights[index];
        return _buildFlightCard(context, flight);
      },
    );
  }

  Widget _buildFlightCard(BuildContext context, FlightModel flight) {
    final s = flight.statistics;
    final dateStr = flight.date.toLocal().toString().substring(0, 10);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: flight.isSampleFlight
              ? Colors.cyanAccent.withAlpha(80)
              : Colors.white10,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Title, Date, Sample Tag, and Overflow Menu
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              flight.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (flight.isSampleFlight) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.cyan.withAlpha(40),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.cyanAccent.withAlpha(100),
                                ),
                              ),
                              child: const Text(
                                'SAMPLE',
                                style: TextStyle(
                                  color: Colors.cyanAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$dateStr ${flight.siteName.isNotEmpty ? "• ${flight.siteName}" : ""}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildUploadStatusBadge(flight),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white70),
                  onSelected: (val) => _handleCardAction(context, flight, val),
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'details',
                      child: ListTile(
                        leading: Icon(Icons.info_outline),
                        title: Text('View Details'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'rename',
                      child: ListTile(
                        leading: Icon(Icons.edit),
                        title: Text('Rename'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'export',
                      child: ListTile(
                        leading: Icon(Icons.share),
                        title: Text('Share / Export'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: flight.uploadStatus == UploadStatus.uploaded
                          ? 'reupload'
                          : flight.uploadStatus == UploadStatus.queued ||
                                  flight.uploadStatus == UploadStatus.failed
                              ? 'retry_upload'
                              : 'upload',
                      child: ListTile(
                        leading: Icon(
                          flight.uploadStatus == UploadStatus.uploaded
                              ? Icons.cloud_done
                              : flight.uploadStatus == UploadStatus.queued ||
                                      flight.uploadStatus == UploadStatus.failed
                                  ? Icons.refresh
                                  : Icons.cloud_upload,
                          color: flight.uploadStatus == UploadStatus.uploaded
                              ? Colors.greenAccent
                              : flight.uploadStatus == UploadStatus.queued ||
                                      flight.uploadStatus == UploadStatus.failed
                                  ? Colors.orangeAccent
                                  : Colors.cyanAccent,
                        ),
                        title: Text(
                          flight.uploadStatus == UploadStatus.uploaded
                              ? 'Re-upload to XContest'
                              : flight.uploadStatus == UploadStatus.queued ||
                                      flight.uploadStatus == UploadStatus.failed
                                  ? 'Retry Upload to XContest'
                                  : 'Upload to XContest',
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete, color: Colors.redAccent),
                        title: Text(
                          'Delete',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Middle Stats Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMiniStat('Duration', _formatDuration(s.duration)),
                _buildMiniStat('Distance', '${s.totalDistanceKm} km'),
                _buildMiniStat('Max Alt', '${s.maxAltitude.toStringAsFixed(0)} m'),
                _buildMiniStat('Max Climb', '+${s.maxClimbRate} m/s'),
              ],
            ),
            const SizedBox(height: 12),

            // Bottom Actions: Replay Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.play_circle_fill, size: 18),
                label: const Text('Replay Flight'),
                onPressed: () => widget.onStartReplay(flight),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadStatusBadge(FlightModel flight) {
    switch (flight.uploadStatus) {
      case UploadStatus.uploaded:
        return const Padding(
          padding: EdgeInsets.only(right: 8),
          child: Tooltip(
            message: 'Uploaded to XContest.org',
            child: Icon(Icons.cloud_done, color: Colors.greenAccent, size: 20),
          ),
        );
      case UploadStatus.queued:
        return const Padding(
          padding: EdgeInsets.only(right: 8),
          child: Tooltip(
            message: 'Upload Queued',
            child: Icon(Icons.cloud_queue, color: Colors.orangeAccent, size: 20),
          ),
        );
      case UploadStatus.uploading:
        return const Padding(
          padding: EdgeInsets.only(right: 8),
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      case UploadStatus.failed:
        return const Padding(
          padding: EdgeInsets.only(right: 8),
          child: Tooltip(
            message: 'Upload Failed',
            child: Icon(Icons.cloud_off, color: Colors.redAccent, size: 20),
          ),
        );
      case UploadStatus.notUploaded:
        return const SizedBox.shrink();
    }
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Future<void> _handleCardAction(
    BuildContext context,
    FlightModel flight,
    String action,
  ) async {
    switch (action) {
      case 'details':
        _showDetailsDialog(context, flight);
        break;
      case 'rename':
        _showRenameDialog(context, flight);
        break;
      case 'export':
        _showExportDialog(context, flight);
        break;
      case 'upload':
      case 'reupload':
      case 'retry_upload':
        final success = await widget.uploadService.uploadFlight(flight);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                success
                    ? 'Flight "${flight.title}" successfully uploaded to XContest.org!'
                    : !widget.uploadService.isOnline
                        ? 'Offline: Flight queued for upload.'
                        : 'Upload failed: Please check XContest username in Settings.',
              ),
              backgroundColor: success ? Colors.green.shade800 : Colors.blueGrey.shade800,
            ),
          );
        }
        break;
      case 'delete':
        _showDeleteConfirmation(context, flight);
        break;
    }
  }

  void _showDetailsDialog(BuildContext context, FlightModel flight) {
    final s = flight.statistics;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(flight.title, style: const TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailItem('Pilot', flight.pilotName),
              _buildDetailItem('Glider', flight.gliderType),
              _buildDetailItem('Site', flight.siteName.isNotEmpty ? flight.siteName : 'N/A'),
              _buildDetailItem('Date', flight.date.toLocal().toString().substring(0, 16)),
              _buildDetailItem('Duration', _formatDuration(s.duration)),
              _buildDetailItem('Distance', '${s.totalDistanceKm} km'),
              _buildDetailItem('Max Altitude', '${s.maxAltitude} m'),
              _buildDetailItem('Min Altitude', '${s.minAltitude} m'),
              _buildDetailItem('Max Climb', '+${s.maxClimbRate} m/s'),
              _buildDetailItem('Max Sink', '${s.maxSinkRate} m/s'),
              _buildDetailItem('Average Speed', '${s.averageSpeedKmh} km/h'),
              _buildDetailItem('Average Glide', '${s.averageGlideRatio} : 1'),
              _buildDetailItem('Points count', '${flight.points.length} points'),
            ],
          ),
        ),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.cloud_upload, size: 18),
            label: const Text('Upload to XContest'),
            onPressed: () {
              Navigator.pop(ctx);
              _handleCardAction(context, flight, 'upload');
            },
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60)),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, FlightModel flight) {
    final controller = TextEditingController(text: flight.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Rename Flight', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'Flight Title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty) {
                widget.storageService.renameFlight(flight.id, newTitle);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, FlightModel flight) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Delete Flight', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete "${flight.title}"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              widget.storageService.deleteFlight(flight.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showExportDialog(BuildContext context, FlightModel flight) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Share & Export Flight', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.description, color: Colors.cyanAccent),
              title: const Text('Export as IGC format', style: TextStyle(color: Colors.white)),
              onTap: () {
                final igc = widget.storageService.exportAsIgc(flight);
                Navigator.pop(ctx);
                _showExportResultDialog(context, 'IGC Export', igc);
              },
            ),
            ListTile(
              leading: const Icon(Icons.code, color: Colors.orangeAccent),
              title: const Text('Export as JSON', style: TextStyle(color: Colors.white)),
              onTap: () {
                final jsonStr = widget.storageService.exportAsJson(flight);
                Navigator.pop(ctx);
                _showExportResultDialog(context, 'JSON Export', jsonStr);
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart, color: Colors.greenAccent),
              title: const Text('Export as CSV', style: TextStyle(color: Colors.white)),
              onTap: () {
                final csv = widget.storageService.exportAsCsv(flight);
                Navigator.pop(ctx);
                _showExportResultDialog(context, 'CSV Export', csv);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showExportResultDialog(BuildContext context, String title, String data) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          height: 250,
          child: SingleChildScrollView(
            child: SelectableText(
              data.length > 2000 ? '${data.substring(0, 2000)}\n... [truncated]' : data,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: Colors.white70,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showImportDialog(BuildContext context) {
    final textController = TextEditingController();
    var selectedCategory = FlightCategory.myFlights;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Import Flight Track', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Paste IGC or JSON track contents below:',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: textController,
                  maxLines: 6,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.white,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'AXFH001...\nB1023034731478N...',
                    filled: true,
                    fillColor: Colors.black26,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Destination Category:',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                RadioGroup<FlightCategory>(
                  groupValue: selectedCategory,
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedCategory = val);
                    }
                  },
                  child: Column(
                    children: const [
                      RadioListTile<FlightCategory>(
                        title: Text('My Flights', style: TextStyle(color: Colors.white)),
                        value: FlightCategory.myFlights,
                      ),
                      RadioListTile<FlightCategory>(
                        title: Text('Planned Flights', style: TextStyle(color: Colors.white)),
                        value: FlightCategory.plannedFlights,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final content = textController.text.trim();
                if (content.isNotEmpty) {
                  await widget.storageService.importFlight(
                    content,
                    filename: 'Imported Flight',
                    category: selectedCategory,
                  );
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Import'),
            ),
          ],
        ),
      ),
    );
  }
}
