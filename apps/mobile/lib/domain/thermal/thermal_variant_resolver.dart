import '../../models/lat_lng.dart';
import 'sunrise.dart';
import 'thermal_variant.dart';

/// Hours after sunrise at which KK7's midday bin starts.
const double kMiddayStartHours = 6.0;

/// Hours after sunrise at which KK7's evening bin starts (KK7 UI: ~9 h).
const double kEveningStartHours = 9.0;

/// Resolves the concrete KK7 [ThermalVariant] for the current settings,
/// date and position. Pure and deterministic; works fully offline.
class ThermalVariantResolver {
  const ThermalVariantResolver._();

  /// Maps a calendar [month] (1-12) to KK7's meteorological season bin.
  static ThermalSeason seasonForMonth(int month) {
    switch (month) {
      case 12:
      case 1:
      case 2:
        return ThermalSeason.jan;
      case 3:
      case 4:
      case 5:
        return ThermalSeason.apr;
      case 6:
      case 7:
      case 8:
        return ThermalSeason.jul;
      default:
        return ThermalSeason.oct;
    }
  }

  /// The season bin following [season] (`oct` -> `jan`).
  static ThermalSeason nextSeason(ThermalSeason season) {
    switch (season) {
      case ThermalSeason.jan:
        return ThermalSeason.apr;
      case ThermalSeason.apr:
        return ThermalSeason.jul;
      case ThermalSeason.jul:
        return ThermalSeason.oct;
      case ThermalSeason.oct:
        return ThermalSeason.jan;
      case ThermalSeason.auto:
      case ThermalSeason.all:
        throw ArgumentError('No next season for $season');
    }
  }

  /// Whether [month] is the last month of its season bin (Feb/May/Aug/Nov).
  static bool isLastMonthOfSeason(int month) => month % 3 == 2;

  /// Maps hours since sunrise to a time-of-day bin. Negative values (before
  /// sunrise) map to morning.
  static ThermalTimeOfDay timeOfDayForHoursSinceSunrise(double hours) {
    if (hours < kMiddayStartHours) return ThermalTimeOfDay.morning;
    if (hours < kEveningStartHours) return ThermalTimeOfDay.midday;
    return ThermalTimeOfDay.evening;
  }

  /// Picks the position used for sunrise: live fix, else last known fix,
  /// else the map view center. Returns null when none is available.
  static LatLng? effectivePosition({
    LatLng? gpsFix,
    LatLng? lastKnownPosition,
    LatLng? mapCenter,
  }) => gpsFix ?? lastKnownPosition ?? mapCenter;

  /// Resolves the time-of-day bin for [now] at [position].
  static ThermalTimeOfDay autoTimeOfDay({
    required DateTime now,
    required LatLng? position,
  }) {
    if (position == null) return ThermalTimeOfDay.all;
    final result = SunriseCalculator.sunrise(
      year: now.year,
      month: now.month,
      day: now.day,
      latitude: position.latitude,
      longitude: position.longitude,
    );
    switch (result) {
      case SunriseAt(:final utc):
        final hours =
            now.toUtc().difference(utc).inSeconds / Duration.secondsPerHour;
        return timeOfDayForHoursSinceSunrise(hours);
      case PolarDay():
      case PolarNight():
        return ThermalTimeOfDay.all;
    }
  }

  /// Resolves the effective variant for the given settings.
  ///
  /// [now] is interpreted in its own time zone for the calendar date (pass
  /// local time on the device).
  static ThermalVariant resolve({
    required ThermalSeason season,
    required ThermalTimeOfDay timeOfDay,
    required DateTime now,
    LatLng? gpsFix,
    LatLng? lastKnownPosition,
    LatLng? mapCenter,
  }) {
    final effectiveSeason = season == ThermalSeason.auto
        ? seasonForMonth(now.month)
        : season;
    final effectiveTime = timeOfDay == ThermalTimeOfDay.auto
        ? autoTimeOfDay(
            now: now,
            position: effectivePosition(
              gpsFix: gpsFix,
              lastKnownPosition: lastKnownPosition,
              mapCenter: mapCenter,
            ),
          )
        : timeOfDay;
    return ThermalVariant(effectiveSeason, effectiveTime);
  }
}
