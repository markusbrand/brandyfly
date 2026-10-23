import 'package:flutter/material.dart';

import '../../models/flight_model.dart';
import '../../services/flight_tracking_service.dart';
import '../../services/screen_manager_service.dart';
import '../../ui/core/widgets/draggable_overlay_container.dart';

/// Free-floating, draggable, and collapsible live recording status overlay.
///
/// Displays:
/// - App name ('BrandyFly')
/// - Operational mode chip ('LIVE' or 'REPLAY')
/// - Live recording state: 'STANDBY', 'REC mm:ss' (elapsed time), 'LANDED', or 'SAVED'
/// - Manual recording start/stop toggle button ([Key] 'btn_manual_record_toggle')
/// - Collapsible platform status details ([Key] 'btn_recording_overlay_collapse' /
///   'btn_recording_overlay_expand')
class RecordingStatusOverlay extends StatefulWidget {
  const RecordingStatusOverlay({
    super.key,
    required this.platformVersion,
    required this.screenManager,
    this.trackingService,
    this.initialPosition,
    this.onPositionChanged,
  });

  final String platformVersion;
  final ScreenManagerService screenManager;
  final FlightTrackingService? trackingService;
  final Offset? initialPosition;
  final ValueChanged<Offset>? onPositionChanged;

  @override
  State<RecordingStatusOverlay> createState() => _RecordingStatusOverlayState();
}

class _RecordingStatusOverlayState extends State<RecordingStatusOverlay> {
  bool _isExpanded = true;

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  Widget _buildContent(BuildContext context) {
    final isReplaying = widget.screenManager.isReplayActive;
    final tracking = widget.trackingService;
    final state = tracking?.state ?? FlightState.groundPreflight;

    Duration elapsed = Duration.zero;
    if (tracking != null &&
        tracking.activeFlightPoints.isNotEmpty &&
        state == FlightState.flying) {
      final start = tracking.activeFlightPoints.first.timestamp;
      final end = tracking.activeFlightPoints.last.timestamp;
      elapsed = end.difference(start);
      if (elapsed.isNegative) elapsed = Duration.zero;
    }

    final borderColor = isReplaying
        ? Colors.cyanAccent.withAlpha(140)
        : Colors.greenAccent.withAlpha(140);

    return Container(
      constraints: const BoxConstraints(maxWidth: 380),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(200),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.drag_indicator,
                size: 14,
                color: Colors.white38,
              ),
              const SizedBox(width: 4),
              const Text(
                'BrandyFly',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              _ModeChip(
                label: isReplaying ? 'REPLAY' : 'LIVE',
                color: isReplaying ? Colors.cyanAccent : Colors.green,
              ),
              if (tracking != null && !isReplaying) ...[
                const SizedBox(width: 6),
                _buildRecordingStateBadge(state, elapsed),
                const SizedBox(width: 4),
                _buildManualToggleButton(state),
              ],
              const SizedBox(width: 4),
              InkWell(
                key: _isExpanded
                    ? const Key('btn_recording_overlay_collapse')
                    : const Key('btn_recording_overlay_expand'),
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 14,
                    color: Colors.white54,
                  ),
                ),
              ),
            ],
          ),
          if (_isExpanded && !isReplaying) ...[
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 18),
              child: Text(
                'Running on: ${widget.platformVersion}',
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 9,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecordingStateBadge(FlightState state, Duration elapsed) {
    switch (state) {
      case FlightState.groundPreflight:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
          decoration: BoxDecoration(
            color: Colors.amber.withAlpha(40),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amberAccent, width: 0.8),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, size: 6, color: Colors.amberAccent),
              SizedBox(width: 3),
              Text(
                'STANDBY',
                style: TextStyle(
                  color: Colors.amberAccent,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      case FlightState.flying:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
          decoration: BoxDecoration(
            color: Colors.redAccent.withAlpha(40),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.redAccent, width: 0.8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.fiber_manual_record, size: 7, color: Colors.redAccent),
              const SizedBox(width: 3),
              Text(
                'REC ${_formatDuration(elapsed)}',
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 8.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      case FlightState.landed:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
          decoration: BoxDecoration(
            color: Colors.lightBlueAccent.withAlpha(40),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.lightBlueAccent, width: 0.8),
          ),
          child: const Text(
            'LANDED',
            style: TextStyle(
              color: Colors.lightBlueAccent,
              fontSize: 8.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      case FlightState.saved:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
          decoration: BoxDecoration(
            color: Colors.tealAccent.withAlpha(40),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.tealAccent, width: 0.8),
          ),
          child: const Text(
            'SAVED',
            style: TextStyle(
              color: Colors.tealAccent,
              fontSize: 8.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
    }
  }

  Widget _buildManualToggleButton(FlightState state) {
    if (state == FlightState.groundPreflight) {
      return InkWell(
        key: const Key('btn_manual_record_toggle'),
        onTap: () => widget.trackingService?.startManualRecording(),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
          decoration: BoxDecoration(
            color: Colors.redAccent.withAlpha(60),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.redAccent, width: 0.8),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.fiber_manual_record, size: 8, color: Colors.redAccent),
              SizedBox(width: 2),
              Text(
                'REC',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    } else if (state == FlightState.flying) {
      return InkWell(
        key: const Key('btn_manual_record_toggle'),
        onTap: () => widget.trackingService?.stopManualRecording(),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
          decoration: BoxDecoration(
            color: Colors.orangeAccent.withAlpha(60),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.orangeAccent, width: 0.8),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.stop, size: 9, color: Colors.orangeAccent),
              SizedBox(width: 2),
              Text(
                'STOP',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final tracking = widget.trackingService;

    return DraggableOverlayContainer(
      cardKey: const Key('recording_status_overlay_card'),
      semanticsLabel: 'Move recording overlay',
      initialAlignment: Alignment.topRight,
      initialPosition: widget.initialPosition,
      margin: const EdgeInsets.only(top: 8, right: 8, bottom: 4, left: 4),
      onPositionChanged: widget.onPositionChanged,
      child: tracking != null
          ? AnimatedBuilder(
              animation: tracking,
              builder: (context, _) => _buildContent(context),
            )
          : _buildContent(context),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withAlpha(40),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 8.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
