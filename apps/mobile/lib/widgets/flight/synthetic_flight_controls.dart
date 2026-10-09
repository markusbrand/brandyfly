import 'package:flutter/material.dart';

import '../../services/telemetry/synthetic_telemetry_source.dart';
import '../../services/telemetry/telemetry_types.dart';

/// Compact simulation controls for the synthetic telemetry source: flight
/// manoeuvre (glide / thermal / sink) and simulated wind drift.
///
/// The simulated wind only moves the ground track; the thermal assistant has
/// to estimate it from circling drift like in a real flight.
class SyntheticFlightControls extends StatefulWidget {
  const SyntheticFlightControls({super.key, required this.source});

  final SyntheticTelemetrySource source;

  @override
  State<SyntheticFlightControls> createState() =>
      _SyntheticFlightControlsState();
}

class _SyntheticFlightControlsState extends State<SyntheticFlightControls> {
  static const _labelStyle = TextStyle(
    fontSize: 9,
    color: Colors.white70,
    fontWeight: FontWeight.w600,
  );

  static const _maneuverLabels = {
    FlightManeuver.steadyGlide: 'Glide',
    FlightManeuver.thermalClimb360: 'Thermal',
    FlightManeuver.sinkRecovery: 'Sink',
  };

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final src = widget.source;
    return Material(
      type: MaterialType.transparency,
      child: Column(
        key: const Key('synthetic_flight_controls'),
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            key: const Key('sim_controls_toggle'),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 14,
                    color: Colors.white70,
                  ),
                  Text(
                    'Sim: ${_maneuverLabels[src.activeManeuver]} · wind '
                    '${src.windSpeedKmh.round()} km/h',
                    style: _labelStyle,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ..._buildControls(src),
        ],
      ),
    );
  }

  List<Widget> _buildControls(SyntheticTelemetrySource src) {
    return [
      Wrap(
        spacing: 4,
        children: [
          for (final e in _maneuverLabels.entries)
            ChoiceChip(
              key: Key('sim_maneuver_${e.key.name}'),
              label: Text(e.value, style: const TextStyle(fontSize: 9)),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              selected: src.activeManeuver == e.key,
              onSelected: (_) => setState(() => src.setManeuver(e.key)),
            ),
        ],
      ),
      Text(
        'Sim wind: ${src.windSpeedKmh.round()} km/h from '
        '${src.windFromDeg.round()}°',
        style: _labelStyle,
      ),
      SizedBox(
        width: 180,
        height: 28,
        child: Slider(
          key: const Key('sim_wind_speed'),
          value: src.windSpeedKmh.clamp(0.0, 40.0),
          max: 40,
          divisions: 40,
          label: '${src.windSpeedKmh.round()} km/h',
          onChanged: (v) => setState(
            () => src.setWind(fromDeg: src.windFromDeg, speedKmh: v),
          ),
        ),
      ),
      SizedBox(
        width: 180,
        height: 28,
        child: Slider(
          key: const Key('sim_wind_dir'),
          value: src.windFromDeg.clamp(0.0, 350.0),
          max: 350,
          divisions: 35,
          label: '${src.windFromDeg.round()}°',
          onChanged: (v) => setState(
            () => src.setWind(fromDeg: v, speedKmh: src.windSpeedKmh),
          ),
        ),
      ),
    ];
  }
}
