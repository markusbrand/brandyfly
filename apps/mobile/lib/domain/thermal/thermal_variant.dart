/// Thermal heatmap season setting. [auto] derives the bin from the date.
///
/// KK7 bins are meteorological quarters with smooth borders built into the
/// data: [jan] = Dec-Feb, [apr] = Mar-May, [jul] = Jun-Aug, [oct] = Sep-Nov.
enum ThermalSeason { auto, all, jan, apr, jul, oct }

/// Thermal heatmap time-of-day setting. [auto] derives the bin from the
/// hours elapsed since local sunrise.
enum ThermalTimeOfDay { auto, all, morning, midday, evening }

extension ThermalSeasonCode on ThermalSeason {
  /// KK7 layer code; throws for [ThermalSeason.auto].
  String get kk7Code {
    switch (this) {
      case ThermalSeason.auto:
        throw StateError('auto has no KK7 code; resolve it first');
      case ThermalSeason.all:
        return 'all';
      case ThermalSeason.jan:
        return 'jan';
      case ThermalSeason.apr:
        return 'apr';
      case ThermalSeason.jul:
        return 'jul';
      case ThermalSeason.oct:
        return 'oct';
    }
  }

  String get label {
    switch (this) {
      case ThermalSeason.auto:
        return 'Auto (date)';
      case ThermalSeason.all:
        return 'All year';
      case ThermalSeason.jan:
        return 'Winter (Dec-Feb)';
      case ThermalSeason.apr:
        return 'Spring (Mar-May)';
      case ThermalSeason.jul:
        return 'Summer (Jun-Aug)';
      case ThermalSeason.oct:
        return 'Autumn (Sep-Nov)';
    }
  }
}

extension ThermalTimeOfDayCode on ThermalTimeOfDay {
  /// KK7 layer code; throws for [ThermalTimeOfDay.auto].
  String get kk7Code {
    switch (this) {
      case ThermalTimeOfDay.auto:
        throw StateError('auto has no KK7 code; resolve it first');
      case ThermalTimeOfDay.all:
        return 'all';
      case ThermalTimeOfDay.morning:
        return '04';
      case ThermalTimeOfDay.midday:
        return '07';
      case ThermalTimeOfDay.evening:
        return '10';
    }
  }

  String get label {
    switch (this) {
      case ThermalTimeOfDay.auto:
        return 'Auto (sunrise)';
      case ThermalTimeOfDay.all:
        return 'All day';
      case ThermalTimeOfDay.morning:
        return 'Morning (0-6 h after sunrise)';
      case ThermalTimeOfDay.midday:
        return 'Midday (6-9 h after sunrise)';
      case ThermalTimeOfDay.evening:
        return 'Evening (>9 h after sunrise)';
    }
  }
}

/// A concrete (non-auto) KK7 thermal layer variant.
class ThermalVariant {
  ThermalVariant(this.season, this.timeOfDay)
    : assert(season != ThermalSeason.auto),
      assert(timeOfDay != ThermalTimeOfDay.auto);

  final ThermalSeason season;
  final ThermalTimeOfDay timeOfDay;

  /// Short key used for directories and URLs, e.g. `jul_07`.
  String get key => '${season.kk7Code}_${timeOfDay.kk7Code}';

  /// KK7 layer id, e.g. `thermals_jul_07`.
  String get layerId => 'thermals_$key';

  /// The four time-of-day variants of [season].
  static List<ThermalVariant> allTimesOf(ThermalSeason season) => const [
    ThermalTimeOfDay.all,
    ThermalTimeOfDay.morning,
    ThermalTimeOfDay.midday,
    ThermalTimeOfDay.evening,
  ].map((t) => ThermalVariant(season, t)).toList();

  /// Parses a [key] such as `jul_07`; returns null when invalid.
  static ThermalVariant? tryParseKey(String key) {
    final parts = key.split('_');
    if (parts.length != 2) return null;
    ThermalSeason? season;
    for (final s in ThermalSeason.values) {
      if (s != ThermalSeason.auto && s.kk7Code == parts[0]) season = s;
    }
    ThermalTimeOfDay? time;
    for (final t in ThermalTimeOfDay.values) {
      if (t != ThermalTimeOfDay.auto && t.kk7Code == parts[1]) time = t;
    }
    if (season == null || time == null) return null;
    return ThermalVariant(season, time);
  }

  @override
  bool operator ==(Object other) =>
      other is ThermalVariant &&
      other.season == season &&
      other.timeOfDay == timeOfDay;

  @override
  int get hashCode => Object.hash(season, timeOfDay);

  @override
  String toString() => 'ThermalVariant($key)';
}
