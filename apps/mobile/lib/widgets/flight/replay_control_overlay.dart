import 'dart:ui';
import 'package:flutter/material.dart';
import '../../services/flight_replay_service.dart';

class ReplayControlOverlay extends StatefulWidget {
  const ReplayControlOverlay({
    super.key,
    required this.replayService,
    required this.onExit,
    this.initiallyExpanded = true,
  });

  final FlightReplayService replayService;
  final VoidCallback onExit;
  final bool initiallyExpanded;

  @override
  State<ReplayControlOverlay> createState() => _ReplayControlOverlayState();
}

class _ReplayControlOverlayState extends State<ReplayControlOverlay> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

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
      animation: widget.replayService,
      builder: (context, _) {
        final elapsed = widget.replayService.elapsedDuration;
        final total = widget.replayService.totalDuration;
        final progress = widget.replayService.progressRatio;
        final isPlaying = widget.replayService.isPlaying;
        final speed = widget.replayService.speedMultiplier;
        final flightTitle = widget.replayService.flight?.title ?? 'Flight Replay';

        return GestureDetector(
          onVerticalDragUpdate: (details) {
            if (details.primaryDelta != null) {
              if (details.primaryDelta! < -6 && !_isExpanded) {
                // Swipe up to expand
                setState(() => _isExpanded = true);
              } else if (details.primaryDelta! > 6 && _isExpanded) {
                // Swipe down to minimize
                setState(() => _isExpanded = false);
              }
            }
          },
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOutCubic,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Material(
                      type: MaterialType.transparency,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: _isExpanded ? 8 : 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.shade900.withAlpha(220),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.cyanAccent.withAlpha(80),
                            width: 1.2,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black54,
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Grab handle / Drag indicator
                            GestureDetector(
                              key: const Key('replay_bottom_grab_handle'),
                              behavior: HitTestBehavior.opaque,
                              onTap: () => setState(() => _isExpanded = !_isExpanded),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.only(top: 2, bottom: 4),
                                child: Center(
                                  child: Container(
                                    width: 40,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: Colors.cyanAccent.withAlpha(120),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Top mini bar: Title + Time stamps + Toggle button + Exit button
                            Row(
                              children: [
                                const Icon(
                                  Icons.history,
                                  color: Colors.cyanAccent,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    flightTitle,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${_formatDuration(elapsed)} / ${_formatDuration(total)}',
                                  style: TextStyle(
                                    color: Colors.cyan.shade200,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                IconButton(
                                  key: Key(_isExpanded ? 'btn_replay_collapse' : 'btn_replay_expand'),
                                  onPressed: () => setState(() => _isExpanded = !_isExpanded),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  iconSize: 20,
                                  tooltip: _isExpanded ? 'Minimize controls' : 'Expand controls',
                                  icon: Icon(
                                    _isExpanded ? Icons.expand_more : Icons.expand_less,
                                    color: Colors.cyanAccent,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                IconButton(
                                  onPressed: widget.onExit,
                                  padding: const EdgeInsets.all(2),
                                  constraints: const BoxConstraints(),
                                  iconSize: 16,
                                  tooltip: 'Close Replay',
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),

                            // Expanded controls (Slider + Playback buttons)
                            if (_isExpanded) ...[
                              const SizedBox(height: 2),
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
                                    widget.replayService.seekToRatio(val);
                                  },
                                ),
                              ),

                              // Bottom row: Controls (Rewind 10s, Play/Pause, Fast Forward 10s, Speed Multiplier)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.replay_10, color: Colors.white70),
                                    iconSize: 20,
                                    tooltip: 'Back 10s',
                                    onPressed: () {
                                      widget.replayService.advance(-10);
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
                                      iconSize: 22,
                                      tooltip: isPlaying ? 'Pause' : 'Play',
                                      onPressed: () {
                                        widget.replayService.togglePlayPause();
                                      },
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.forward_10, color: Colors.white70),
                                    iconSize: 20,
                                    tooltip: 'Forward 10s',
                                    onPressed: () {
                                      widget.replayService.advance(10);
                                    },
                                  ),
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.cyanAccent,
                                      side: const BorderSide(color: Colors.cyanAccent),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: () {
                                      widget.replayService.cycleSpeedMultiplier();
                                    },
                                    child: Text(
                                      '${speed}x',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
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
