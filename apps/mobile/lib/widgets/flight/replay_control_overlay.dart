import 'dart:ui';
import 'package:flutter/material.dart';
import '../../services/flight_replay_service.dart';

class ReplayControlOverlay extends StatelessWidget {
  const ReplayControlOverlay({
    super.key,
    required this.replayService,
    required this.onExit,
  });

  final FlightReplayService replayService;
  final VoidCallback onExit;

  String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: replayService,
      builder: (context, _) {
        final elapsed = replayService.elapsedDuration;
        final total = replayService.totalDuration;
        final progress = replayService.progressRatio;
        final isPlaying = replayService.isPlaying;
        final speed = replayService.speedMultiplier;
        final flightTitle = replayService.flight?.title ?? 'Flight Replay';

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Material(
                  type: MaterialType.transparency,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.shade900.withAlpha(225),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.cyanAccent.withAlpha(80), width: 1.2),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black54,
                          blurRadius: 16,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Top mini bar: Title + Time stamps + Exit button
                        Row(
                          children: [
                            const Icon(
                              Icons.history,
                              color: Colors.cyanAccent,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                flightTitle,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Text(
                              '${_formatDuration(elapsed)} / ${_formatDuration(total)}',
                              style: TextStyle(
                                color: Colors.cyan.shade200,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: onExit,
                              borderRadius: BorderRadius.circular(16),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(
                                  Icons.close,
                                  color: Colors.white70,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),

                        // Middle: Progress Slider
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                            activeTrackColor: Colors.cyanAccent,
                            inactiveTrackColor: Colors.white24,
                            thumbColor: Colors.cyanAccent,
                          ),
                          child: Slider(
                            value: progress,
                            onChanged: (val) {
                              replayService.seekToRatio(val);
                            },
                          ),
                        ),

                        // Bottom row: Controls (Rewind 10s, Play/Pause, Fast Forward 10s, Speed Multiplier)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.replay_10, color: Colors.white70),
                              iconSize: 22,
                              tooltip: 'Back 10s',
                              onPressed: () {
                                replayService.advance(-10);
                              },
                            ),
                            Container(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.cyanAccent,
                              ),
                              child: IconButton(
                                icon: Icon(
                                  isPlaying ? Icons.pause : Icons.play_arrow,
                                  color: Colors.black,
                                ),
                                iconSize: 24,
                                tooltip: isPlaying ? 'Pause' : 'Play',
                                onPressed: () {
                                  replayService.togglePlayPause();
                                },
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.forward_10, color: Colors.white70),
                              iconSize: 22,
                              tooltip: 'Forward 10s',
                              onPressed: () {
                                replayService.advance(10);
                              },
                            ),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.cyanAccent,
                                side: const BorderSide(color: Colors.cyanAccent),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () {
                                replayService.cycleSpeedMultiplier();
                              },
                              child: Text(
                                '${speed}x',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
