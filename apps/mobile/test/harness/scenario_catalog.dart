import 'package:brandyfly/domain/models/cockpit_telemetry.dart';
import 'package:brandyfly/models/lat_lng.dart';
import 'package:brandyfly/domain/thermal_assistant/thermal_assistant_engine.dart';

/// Represents a discrete snapshot in a flight replay scenario.
class ReplayStep {
  const ReplayStep({
    required this.elapsed,
    required this.telemetry,
    this.milestone,
  });

  /// Elapsed time from the start of the scenario.
  final Duration elapsed;

  /// Cockpit telemetry values at this step.
  final CockpitTelemetry telemetry;

  /// Optional milestone tag (e.g., 'entry', 'peak', 'recovery').
  final String? milestone;
}

/// Represents a notable milestone keyframe within a scenario.
class ReplayMilestone {
  const ReplayMilestone({
    required this.name,
    required this.elapsed,
    this.description,
  });

  /// Milestone identifier (e.g. 'entry', 'peak', 'sink_alarm').
  final String name;

  /// Elapsed duration when the milestone occurs.
  final Duration elapsed;

  /// Optional description of the milestone.
  final String? description;
}

/// Declarative representation of a flight replay scenario.
class ReplayScenario {
  const ReplayScenario({
    required this.id,
    required this.name,
    required this.description,
    required this.duration,
    required this.steps,
    required this.milestones,
  });

  final String id;
  final String name;
  final String description;
  final Duration duration;
  final List<ReplayStep> steps;
  final List<ReplayMilestone> milestones;

  /// Returns the telemetry snapshot active at [elapsed].
  CockpitTelemetry telemetryAt(Duration elapsed) {
    if (steps.isEmpty) {
      return const CockpitTelemetry();
    }
    ReplayStep latest = steps.first;
    for (final step in steps) {
      if (step.elapsed <= elapsed) {
        latest = step;
      } else {
        break;
      }
    }
    return latest.telemetry;
  }
}

/// Canonical catalog of flight replay test scenarios.
class ScenarioCatalog {
  ScenarioCatalog._();

  /// 1. Steady Glide: laminar air, stable L/D, gentle sink, valid wind estimate.
  static ReplayScenario get steadyGlide => ReplayScenario(
        id: 'steady_glide',
        name: 'Steady Glide',
        description: 'Laminar glide with stable speed and sink',
        duration: const Duration(seconds: 10),
        milestones: const [
          ReplayMilestone(
            name: 'entry',
            elapsed: Duration.zero,
            description: 'Glide entry at trim speed',
          ),
          ReplayMilestone(
            name: 'mid_glide',
            elapsed: Duration(seconds: 5),
            description: 'Midpoint steady glide',
          ),
          ReplayMilestone(
            name: 'final',
            elapsed: Duration(seconds: 10),
            description: 'End of glide phase',
          ),
        ],
        steps: [
          for (var i = 0; i <= 10; i++)
            ReplayStep(
              elapsed: Duration(seconds: i),
              telemetry: CockpitTelemetry(
                altitude: 1850.0 - (i * 1.2),
                speed: 39.5,
                glide: 8.8,
                hag: 650.0 - (i * 1.2),
                climb: -1.2,
                averageClimb: -1.15,
                windDir: 260.0,
                windSpeed: 14.0,
                windStale: false,
                latitude: 47.520 + (i * 0.0005),
                longitude: 13.680 + (i * 0.0008),
                heading: 55.0,
                hasSource: true,
                history: [
                  1855.0,
                  1852.0,
                  1850.0 - (i * 1.2),
                ],
              ),
              milestone: i == 0
                  ? 'entry'
                  : i == 5
                      ? 'mid_glide'
                      : i == 10
                          ? 'final'
                          : null,
            ),
        ],
      );

  /// 2. Thermal Climb: circling state active, positive climb, wind vector.
  static ReplayScenario get thermalClimb {
    final now = DateTime.utc(2026, 10, 18, 12, 0, 0);
    return ReplayScenario(
      id: 'thermal_climb',
      name: 'Thermal Climb',
      description: 'Circling in positive lift with active thermal assistant',
      duration: const Duration(seconds: 15),
      milestones: const [
        ReplayMilestone(
          name: 'entry',
          elapsed: Duration.zero,
          description: 'Thermal entry transition',
        ),
        ReplayMilestone(
          name: 'core_peak',
          elapsed: Duration(seconds: 8),
          description: 'Peak core climb rate',
        ),
        ReplayMilestone(
          name: 'exit',
          elapsed: Duration(seconds: 15),
          description: 'Thermal exit into glide',
        ),
      ],
      steps: [
        for (var i = 0; i <= 15; i++)
          ReplayStep(
            elapsed: Duration(seconds: i),
            telemetry: CockpitTelemetry(
              altitude: 1400.0 + (i * 3.2),
              speed: 35.0,
              glide: 0.0,
              hag: 500.0 + (i * 3.2),
              climb: i < 8 ? 1.5 + (i * 0.3) : 3.9 - ((i - 8) * 0.25),
              averageClimb: 2.8,
              windDir: 275.0,
              windSpeed: 16.5,
              windStale: false,
              latitude: 47.525,
              longitude: 13.685,
              heading: (i * 45.0) % 360.0,
              hasSource: true,
              thermal: ThermalAssistantState(
                mode: const FlightModeState.circling(TurnDirection.right),
                timestamp: now.add(Duration(seconds: i)),
                wind: WindEstimate(
                  directionDeg: 275.0,
                  speedKmh: 16.5,
                  updatedAt: now.add(Duration(seconds: i)),
                  isStale: false,
                ),
                core: const GeoPosition(47.526, 13.686),
                session: ThermalSessionStats(
                  entryAltitudeM: 1400.0,
                  currentAltitudeM: 1400.0 + (i * 3.2),
                  altitudeGainM: i * 3.2,
                  averageClimbMs: 2.8,
                  duration: Duration(seconds: i),
                  turnCount: (i / 4).clamp(1, 10).toInt(),
                  peakClimbMs: 3.9,
                  isLive: true,
                ),
              ),
              thermalSession: ThermalSessionStats(
                entryAltitudeM: 1400.0,
                currentAltitudeM: 1400.0 + (i * 3.2),
                altitudeGainM: i * 3.2,
                averageClimbMs: 2.8,
                duration: Duration(seconds: i),
                turnCount: (i / 4).clamp(1, 10).toInt(),
                peakClimbMs: 3.9,
                isLive: true,
              ),
              history: [
                1400.0,
                1410.0,
                1400.0 + (i * 3.2),
              ],
            ),
            milestone: i == 0
                ? 'entry'
                : i == 8
                    ? 'core_peak'
                    : i == 15
                        ? 'exit'
                        : null,
          ),
      ],
    );
  }

  /// 3. Heavy Sink: sink alarm, red vario indication, low HAG proximity.
  static ReplayScenario get heavySink => ReplayScenario(
        id: 'heavy_sink',
        name: 'Heavy Sink',
        description: 'Strong downdraft with rapid descent and low HAG warning',
        duration: const Duration(seconds: 10),
        milestones: const [
          ReplayMilestone(
            name: 'sink_entry',
            elapsed: Duration.zero,
            description: 'Initial entry into sink air mass',
          ),
          ReplayMilestone(
            name: 'maximum_sink',
            elapsed: Duration(seconds: 5),
            description: 'Maximum sink rate reaching -4.2 m/s',
          ),
          ReplayMilestone(
            name: 'recovery',
            elapsed: Duration(seconds: 10),
            description: 'Sink recovery and flare prep',
          ),
        ],
        steps: [
          for (var i = 0; i <= 10; i++)
            ReplayStep(
              elapsed: Duration(seconds: i),
              telemetry: CockpitTelemetry(
                altitude: 950.0 - (i * 4.0),
                speed: 52.0,
                glide: 3.4,
                hag: 200.0 - (i * 12.0),
                climb: i <= 5 ? -2.0 - (i * 0.44) : -4.2 + ((i - 5) * 0.35),
                averageClimb: -3.6,
                windDir: 190.0,
                windSpeed: 24.0,
                windStale: false,
                latitude: 47.530,
                longitude: 13.690,
                heading: 180.0,
                hasSource: true,
                history: [
                  970.0,
                  960.0,
                  950.0 - (i * 4.0),
                ],
              ),
              milestone: i == 0
                  ? 'sink_entry'
                  : i == 5
                      ? 'maximum_sink'
                      : i == 10
                          ? 'recovery'
                          : null,
            ),
        ],
      );

  /// 4. Airspace Alert: boundary proximity and penetration scenario.
  static ReplayScenario get airspaceAlert => ReplayScenario(
        id: 'airspace_alert',
        name: 'Airspace Alert',
        description: 'Controlled airspace proximity and boundary transition',
        duration: const Duration(seconds: 12),
        milestones: const [
          ReplayMilestone(
            name: 'approach',
            elapsed: Duration.zero,
            description: 'Approaching CTR boundary corridor',
          ),
          ReplayMilestone(
            name: 'boundary_crossing',
            elapsed: Duration(seconds: 6),
            description: 'Penetrating restricted sector',
          ),
          ReplayMilestone(
            name: 'violation',
            elapsed: Duration(seconds: 12),
            description: 'Airspace infringement alert active',
          ),
        ],
        steps: [
          for (var i = 0; i <= 12; i++)
            ReplayStep(
              elapsed: Duration(seconds: i),
              telemetry: CockpitTelemetry(
                altitude: 2100.0 + (i * 5.0),
                speed: 46.0,
                glide: 7.5,
                hag: 900.0,
                climb: 0.5,
                averageClimb: 0.4,
                latitude: 47.780 + (i * 0.002),
                longitude: 13.000 + (i * 0.003),
                heading: 35.0,
                hasSource: true,
                trackPoints: [
                  LatLng(47.780, 13.000),
                  LatLng(47.780 + (i * 0.002), 13.000 + (i * 0.003)),
                ],
              ),
              milestone: i == 0
                  ? 'approach'
                  : i == 6
                      ? 'boundary_crossing'
                      : i == 12
                          ? 'violation'
                          : null,
            ),
        ],
      );

  /// 5. Sensor Dropouts: stale telemetry, baro disconnect, lost GPS fix.
  static ReplayScenario get sensorDropouts => ReplayScenario(
        id: 'sensor_dropouts',
        name: 'Sensor Dropouts',
        description: 'Simulated sensor disconnection, stale states, and recovery',
        duration: const Duration(seconds: 10),
        milestones: const [
          ReplayMilestone(
            name: 'nominal',
            elapsed: Duration.zero,
            description: 'Nominal sensor inputs',
          ),
          ReplayMilestone(
            name: 'gps_lost',
            elapsed: Duration(seconds: 5),
            description: 'Sensors stale and coordinates unavailable',
          ),
          ReplayMilestone(
            name: 'stale_recovery',
            elapsed: Duration(seconds: 10),
            description: 'Signal re-acquisition and sync',
          ),
        ],
        steps: [
          for (var i = 0; i <= 10; i++)
            ReplayStep(
              elapsed: Duration(seconds: i),
              telemetry: (i >= 4 && i <= 7)
                  ? const CockpitTelemetry(
                      altitude: 1650.0,
                      speed: 0.0,
                      glide: 0.0,
                      hag: null,
                      climb: 0.0,
                      isStale: true,
                      windStale: true,
                      hasSource: false,
                    )
                  : CockpitTelemetry(
                      altitude: 1650.0 - (i * 1.0),
                      speed: 40.0,
                      glide: 8.0,
                      hag: 450.0,
                      climb: -1.0,
                      latitude: 47.525,
                      longitude: 13.685,
                      isStale: false,
                      windStale: false,
                      hasSource: true,
                    ),
              milestone: i == 0
                  ? 'nominal'
                  : i == 5
                      ? 'gps_lost'
                      : i == 10
                          ? 'stale_recovery'
                          : null,
            ),
        ],
      );

  /// 6. Boundary Extremes: 4-digit altitude, 3-digit speed, negative HAG.
  static ReplayScenario get boundaryExtremes => ReplayScenario(
        id: 'boundary_extremes',
        name: 'Boundary Extremes',
        description: 'Boundary values: four-digit altitude, high speed, negative HAG',
        duration: const Duration(seconds: 8),
        milestones: const [
          ReplayMilestone(
            name: 'extreme_high',
            elapsed: Duration.zero,
            description: 'High altitude (4850 m) and climb (+9.9 m/s)',
          ),
          ReplayMilestone(
            name: 'extreme_speed',
            elapsed: Duration(seconds: 4),
            description: 'Triple-digit speed (124.5 km/h) and extreme sink',
          ),
          ReplayMilestone(
            name: 'negative_hag',
            elapsed: Duration(seconds: 8),
            description: 'Negative HAG (-18 m) below ground reference',
          ),
        ],
        steps: [
          const ReplayStep(
            elapsed: Duration.zero,
            telemetry: CockpitTelemetry(
              altitude: 4850.0,
              speed: 45.0,
              glide: 14.5,
              hag: 3450.0,
              climb: 9.9,
              averageClimb: 8.5,
              windDir: 350.0,
              windSpeed: 48.0,
              latitude: 47.525,
              longitude: 13.685,
              heading: 355.0,
              hasSource: true,
            ),
            milestone: 'extreme_high',
          ),
          const ReplayStep(
            elapsed: Duration(seconds: 4),
            telemetry: CockpitTelemetry(
              altitude: 3100.0,
              speed: 124.5,
              glide: 26.8,
              hag: 1200.0,
              climb: -9.9,
              averageClimb: -8.0,
              windDir: 180.0,
              windSpeed: 65.0,
              latitude: 47.600,
              longitude: 13.800,
              heading: 175.0,
              hasSource: true,
            ),
            milestone: 'extreme_speed',
          ),
          const ReplayStep(
            elapsed: Duration(seconds: 8),
            telemetry: CockpitTelemetry(
              altitude: 450.0,
              speed: 28.0,
              glide: 5.2,
              hag: -18.0,
              climb: -0.8,
              averageClimb: -0.6,
              windDir: 90.0,
              windSpeed: 5.0,
              latitude: -89.5,
              longitude: 179.9,
              heading: 90.0,
              hasSource: true,
            ),
            milestone: 'negative_hag',
          ),
        ],
      );

  /// All registered scenarios in the catalog.
  static List<ReplayScenario> get all => [
        steadyGlide,
        thermalClimb,
        heavySink,
        airspaceAlert,
        sensorDropouts,
        boundaryExtremes,
      ];

  /// Find scenario by unique identifier.
  static ReplayScenario byId(String id) {
    return all.firstWhere(
      (s) => s.id == id,
      orElse: () => throw ArgumentError('Scenario not found: $id'),
    );
  }
}
