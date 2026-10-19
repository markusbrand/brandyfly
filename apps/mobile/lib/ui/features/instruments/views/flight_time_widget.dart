import 'package:flutter/material.dart';

import '../../../../domain/models/size_tier.dart';
import '../../../core/theme/cockpit_tokens.dart';

/// Cockpit instrument widget displaying elapsed flight duration,
/// current local clock time, and takeoff timestamp.
class FlightTimeWidget extends StatelessWidget {
  const FlightTimeWidget({
    super.key,
    this.flightDuration,
    this.takeoffTime,
    this.localTime,
    this.isStale = false,
    this.tier,
  });

  final Duration? flightDuration;
  final DateTime? takeoffTime;
  final DateTime? localTime;
  final bool isStale;
  final SizeTier? tier;

  bool get isStandby => takeoffTime == null || flightDuration == null;

  static String formatDuration(Duration? duration) {
    if (duration == null || duration <= Duration.zero) {
      return '00:00';
    }
    final totalSeconds = duration.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  static String formatClock(DateTime? time) {
    if (time == null) return '--:--';
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  static String formatTakeoff(DateTime? time) {
    if (time == null) return '--:--';
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final durationStr = formatDuration(flightDuration);
    final semantic = isStandby
        ? 'Flight time: standby'
        : 'Flight time: $durationStr${isStale ? ', data stale' : ''}';

    return Semantics(
      label: semantic,
      readOnly: true,
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxHeight < 6 || constraints.maxWidth < 6) {
            return const SizedBox.shrink();
          }
          final effectiveTier =
              tier ?? sizeTierFor(constraints.maxWidth, constraints.maxHeight);

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(160),
              borderRadius: BorderRadius.circular(6.0),
              border: Border.all(
                color: isStale
                    ? CockpitTokens.cautionAmber.withAlpha(180)
                    : Colors.white24,
                width: 1.0,
              ),
            ),
            child: _buildContent(context, effectiveTier, durationStr),
          );
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    SizeTier effectiveTier,
    String durationStr,
  ) {
    if (effectiveTier == SizeTier.tiny) {
      return _buildTiny(durationStr);
    }
    if (effectiveTier == SizeTier.compact) {
      return _buildCompact(durationStr);
    }
    return _buildRegular(context, durationStr);
  }

  Widget _buildTiny(String durationStr) {
    return Center(
      child: FittedBox(
        fit: BoxFit.contain,
        child: Text(
          durationStr,
          style: CockpitTokens.instrumentValue.copyWith(
            color: isStale
                ? CockpitTokens.cautionAmber
                : (isStandby ? CockpitTokens.inkMuted : CockpitTokens.ink),
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildCompact(String durationStr) {
    final effectiveClock = localTime ?? DateTime.now();
    final clockStr =
        '${effectiveClock.hour.toString().padLeft(2, '0')}:${effectiveClock.minute.toString().padLeft(2, '0')}';

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'FLIGHT TIME',
                  style: CockpitTokens.instrumentLabel.copyWith(
                    fontSize: 10,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: isStale
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 3, vertical: 1),
                        decoration: BoxDecoration(
                          color: CockpitTokens.cautionAmber.withAlpha(50),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: const Text(
                          'STALE',
                          style: TextStyle(
                            color: CockpitTokens.cautionAmber,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : isStandby
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 3, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: const Text(
                              'STANDBY',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : Text(
                            clockStr,
                            style: CockpitTokens.instrumentLabel.copyWith(
                              fontSize: 9,
                              color: Colors.white60,
                            ),
                          ),
              ),
            ),
          ],
        ),
        Expanded(
          child: Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: Text(
                durationStr,
                style: CockpitTokens.instrumentValue.copyWith(
                  color: isStale
                      ? CockpitTokens.cautionAmber
                      : (isStandby ? CockpitTokens.inkMuted : CockpitTokens.ink),
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegular(BuildContext context, String durationStr) {
    final effectiveClock = localTime ?? DateTime.now();
    final clockStr = formatClock(effectiveClock);
    final toStr = formatTakeoff(takeoffTime);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'FLIGHT TIME',
                  style: CockpitTokens.instrumentLabel.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            if (isStale)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: CockpitTokens.cautionAmber.withAlpha(60),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: CockpitTokens.cautionAmber,
                    width: 0.8,
                  ),
                ),
                child: const Text(
                  'STALE',
                  style: TextStyle(
                    color: CockpitTokens.cautionAmber,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else if (isStandby)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: Colors.white24, width: 0.8),
                ),
                child: const Text(
                  'STANDBY',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: CockpitTokens.liftGreen.withAlpha(40),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: CockpitTokens.liftGreen.withAlpha(160),
                    width: 0.8,
                  ),
                ),
                child: const Text(
                  'AIRBORNE',
                  style: TextStyle(
                    color: CockpitTokens.liftGreen,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        Expanded(
          child: Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: Text(
                durationStr,
                style: CockpitTokens.instrumentValue.copyWith(
                  color: isStale
                      ? CockpitTokens.cautionAmber
                      : (isStandby ? CockpitTokens.inkMuted : CockpitTokens.ink),
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'TIME $clockStr',
                  style: CockpitTokens.instrumentLabel.copyWith(
                    fontSize: 10,
                    color: Colors.white70,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  'TAKEOFF $toStr',
                  style: CockpitTokens.instrumentLabel.copyWith(
                    fontSize: 10,
                    color: Colors.white70,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
