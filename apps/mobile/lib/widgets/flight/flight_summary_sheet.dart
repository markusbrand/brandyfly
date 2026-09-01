import 'package:flutter/material.dart';
import '../../models/flight_model.dart';
import '../../services/flight_storage_service.dart';
import '../../services/xcontest_upload_service.dart';

class FlightSummarySheet extends StatefulWidget {
  const FlightSummarySheet({
    super.key,
    required this.flight,
    required this.storageService,
    required this.uploadService,
    required this.onViewInLogbook,
    required this.onDismiss,
  });

  final FlightModel flight;
  final FlightStorageService storageService;
  final XContestUploadService uploadService;
  final VoidCallback onViewInLogbook;
  final VoidCallback onDismiss;

  static Future<void> show(
    BuildContext context, {
    required FlightModel flight,
    required FlightStorageService storageService,
    required XContestUploadService uploadService,
    required VoidCallback onViewInLogbook,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FlightSummarySheet(
        flight: flight,
        storageService: storageService,
        uploadService: uploadService,
        onViewInLogbook: () {
          Navigator.pop(ctx);
          onViewInLogbook();
        },
        onDismiss: () => Navigator.pop(ctx),
      ),
    );
  }

  @override
  State<FlightSummarySheet> createState() => _FlightSummarySheetState();
}

class _FlightSummarySheetState extends State<FlightSummarySheet> {
  bool _isUploading = false;
  String? _uploadMessage;

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    final seconds = d.inSeconds % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    }
    return '${minutes}m ${seconds}s';
  }

  Future<void> _handleUpload() async {
    setState(() {
      _isUploading = true;
      _uploadMessage = null;
    });

    final success = await widget.uploadService.uploadFlight(widget.flight);
    if (!mounted) return;

    setState(() {
      _isUploading = false;
      if (success) {
        _uploadMessage = 'Flight successfully uploaded to XContest.org!';
      } else if (!widget.uploadService.isOnline) {
        _uploadMessage = 'Offline: Flight queued for automatic upload.';
      } else {
        _uploadMessage = 'Upload failed. Check XContest credentials in Settings.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.flight.statistics;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade900,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white24),
      ),
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header: Title & Landing badge
            Row(
              children: [
                const Icon(Icons.flight_land, color: Colors.greenAccent, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Flight Completed',
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.flight.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  tooltip: 'Close',
                  onPressed: widget.onDismiss,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Mini route preview container
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CustomPaint(
                  painter: _MiniTrackPainter(widget.flight.points),
                  child: const Center(
                    child: Text(
                      'Track Preview',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Statistics Grid
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.timer,
                    label: 'Duration',
                    value: _formatDuration(s.duration),
                    color: Colors.lightBlueAccent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    icon: Icons.straighten,
                    label: 'Distance',
                    value: '${s.totalDistanceKm} km',
                    color: Colors.orangeAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.landscape,
                    label: 'Max Altitude',
                    value: '${s.maxAltitude.toStringAsFixed(0)} m',
                    color: Colors.cyanAccent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    icon: Icons.speed,
                    label: 'Avg Speed',
                    value: '${s.averageSpeedKmh} km/h',
                    color: Colors.purpleAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.arrow_upward,
                    label: 'Max Climb',
                    value: '+${s.maxClimbRate} m/s',
                    color: Colors.greenAccent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    icon: Icons.arrow_downward,
                    label: 'Max Sink',
                    value: '${s.maxSinkRate} m/s',
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_uploadMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _uploadMessage!,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),

            // Action Buttons
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: _isUploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.cloud_upload),
              label: Text(_isUploading ? 'Uploading...' : 'Upload to XContest.org'),
              onPressed: _isUploading ? null : _handleUpload,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.menu_book),
              label: const Text('View in Logbook'),
              onPressed: widget.onViewInLogbook,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniTrackPainter extends CustomPainter {
  const _MiniTrackPainter(this.points);

  final List<FlightPoint> points;

  // ⚡ Bolt: Cache Paint objects statically to avoid per-frame GC allocations
  static final Paint _trackPaint = Paint()
    ..color = Colors.cyanAccent
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLon = points.first.longitude;
    var maxLon = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLon) minLon = p.longitude;
      if (p.longitude > maxLon) maxLon = p.longitude;
    }

    final latSpan = (maxLat - minLat).clamp(0.0001, 100.0);
    final lonSpan = (maxLon - minLon).clamp(0.0001, 100.0);

    final path = Path();

    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final x = 20.0 + ((p.longitude - minLon) / lonSpan) * (size.width - 40.0);
      final y = size.height - 20.0 - (((p.latitude - minLat) / latSpan) * (size.height - 40.0));

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, _trackPaint);
  }

  @override
  bool shouldRepaint(covariant _MiniTrackPainter oldDelegate) => oldDelegate.points != points;
}
