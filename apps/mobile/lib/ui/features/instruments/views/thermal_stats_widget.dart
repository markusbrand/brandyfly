import 'package:flutter/material.dart';

import '../../../../domain/models/size_tier.dart';
import '../../../../domain/thermal_assistant/thermal_session_stats.dart';
import '../../../core/theme/cockpit_tokens.dart';

/// Cockpit flight instrument displaying thermal session climb metrics.
class ThermalStatsWidget extends StatelessWidget {
  const ThermalStatsWidget({
    super.key,
    this.stats,
    this.tier,
  });

  final ThermalSessionStats? stats;
  final SizeTier? tier;

  @override
  Widget build(BuildContext context) {
    final s = stats ?? ThermalSessionStats.empty;
    final hasSession = stats != null && (s.isLive || s.duration > Duration.zero);

    return Semantics(
      label: hasSession
          ? 'Thermal ${s.isLive ? 'live' : 'last'}: gain ${s.altitudeGainM.toInt()} meters, '
              'average ${s.averageClimbMs.toStringAsFixed(1)} meters per second, '
              'duration ${s.duration.inMinutes} minutes, ${s.turnCount} turns'
          : 'Thermal stats: no thermal session',
      readOnly: true,
      child: Container(
        padding: const EdgeInsets.all(4.0),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(160),
          borderRadius: BorderRadius.circular(6.0),
          border: Border.all(
            color: s.isLive
                ? const Color(0xFF00E676).withAlpha(120)
                : Colors.white24,
            width: 1.0,
          ),
        ),
        child: _buildContent(context, s, hasSession),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ThermalSessionStats s,
    bool hasSession,
  ) {
    if (tier == SizeTier.tiny) {
      return _buildTiny(s, hasSession);
    }
    if (tier == SizeTier.compact) {
      return _buildCompact(s, hasSession);
    }
    return _buildRegular(context, s, hasSession);
  }

  Widget _buildTiny(ThermalSessionStats s, bool hasSession) {
    final gain = s.altitudeGainM.round();
    final text = hasSession ? '${gain >= 0 ? '+' : ''}$gain' : '--';
    return Center(
      child: FittedBox(
        fit: BoxFit.contain,
        child: Text(
          text,
          style: CockpitTokens.instrumentValue.copyWith(
            color: gain >= 0 ? CockpitTokens.liftGreen : CockpitTokens.sinkRed,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _buildCompact(ThermalSessionStats s, bool hasSession) {
    final gain = s.altitudeGainM.round();
    final avg = s.averageClimbMs;
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                hasSession ? '${gain >= 0 ? '+' : ''}${gain}m' : '--',
                style: TextStyle(
                  color: gain >= 0 ? const Color(0xFF00E676) : Colors.redAccent,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 4),
              Text(
                hasSession
                    ? 'ø${avg >= 0 ? '+' : ''}${avg.toStringAsFixed(1)}'
                    : 'ø--',
                style: const TextStyle(
                  color: Colors.amberAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
        if (hasSession)
          Text(
            s.isLive ? 'LIVE THERMAL' : 'LAST THERMAL',
            style: TextStyle(
              color: s.isLive ? const Color(0xFF00E676) : Colors.white60,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );
  }

  Widget _buildRegular(
    BuildContext context,
    ThermalSessionStats s,
    bool hasSession,
  ) {
    final gain = s.altitudeGainM.round();
    final avg = s.averageClimbMs;
    final mins = s.duration.inMinutes;
    final secs = (s.duration.inSeconds % 60).toString().padLeft(2, '0');
    final timeStr = '$mins:$secs';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top header row: Badge & Turn Count
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: s.isLive
                      ? const Color(0xFF00E676).withAlpha(40)
                      : Colors.white10,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: s.isLive
                        ? const Color(0xFF00E676).withAlpha(160)
                        : Colors.white24,
                    width: 0.8,
                  ),
                ),
                child: Text(
                  !hasSession
                      ? 'IDLE'
                      : (s.isLive ? 'LIVE THERMAL' : 'LAST THERMAL'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: s.isLive ? const Color(0xFF00E676) : Colors.white70,
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            if (hasSession) ...[
              const SizedBox(width: 4),
              Text(
                '${s.turnCount} ${s.turnCount == 1 ? 'turn' : 'turns'}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),

        // Primary metrics: Gain and Average Climb
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _buildMetricBox(
                  label: 'GAIN',
                  value: hasSession ? '${gain >= 0 ? '+' : ''}${gain}m' : '--',
                  color: gain >= 0 ? const Color(0xFF00E676) : Colors.redAccent,
                  isPrimary: true,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildMetricBox(
                  label: 'AVG CLIMB',
                  value: hasSession
                      ? '${avg >= 0 ? '+' : ''}${avg.toStringAsFixed(1)}'
                      : '--',
                  color: Colors.amberAccent,
                  unit: 'm/s',
                  isPrimary: true,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),

        // Secondary metrics: Time and Peak
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _buildMetricBox(
                  label: 'TIME',
                  value: hasSession ? timeStr : '--:--',
                  color: Colors.white,
                  isPrimary: false,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildMetricBox(
                  label: 'PEAK',
                  value: hasSession
                      ? '+${s.peakClimbMs.toStringAsFixed(1)}'
                      : '--',
                  color: const Color(0xFF00E676),
                  unit: 'm/s',
                  isPrimary: false,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricBox({
    required String label,
    required String value,
    required Color color,
    String? unit,
    required bool isPrimary,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 7.5,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: isPrimary ? 16 : 12,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                  ),
                ),
                if (unit != null) ...[
                  const SizedBox(width: 2),
                  Text(
                    unit,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
