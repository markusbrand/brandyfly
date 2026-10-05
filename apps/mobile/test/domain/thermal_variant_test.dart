import 'package:brandyfly/domain/thermal/kk7_provider.dart';
import 'package:brandyfly/domain/thermal/sunrise.dart';
import 'package:brandyfly/domain/thermal/thermal_variant.dart';
import 'package:brandyfly/domain/thermal/thermal_variant_resolver.dart';
import 'package:brandyfly/models/lat_lng.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Kk7Provider', () {
    test('builds TMS tile URL with src tracking parameter', () {
      final uri = Kk7Provider.tileUri(
        ThermalVariant(ThermalSeason.jul, ThermalTimeOfDay.midday),
        10,
        545,
        664,
      );
      // TMS y = 2^10 - 1 - 664 = 359
      expect(
        uri.toString(),
        'https://thermal.kk7.ch/tiles/thermals_jul_07/10/545/359.png?src=brandyfly',
      );
      expect(uri.queryParameters, {'src': 'brandyfly'});
    });

    test('xyz to tms flip is an involution', () {
      for (final z in [0, 1, 5, 12]) {
        for (final y in [0, (1 << z) - 1, (1 << z) ~/ 2]) {
          expect(Kk7Provider.xyzToTmsY(z, Kk7Provider.xyzToTmsY(z, y)), y);
        }
      }
    });
  });

  group('ThermalVariant', () {
    const seasonCodes = {
      ThermalSeason.all: 'all',
      ThermalSeason.jan: 'jan',
      ThermalSeason.apr: 'apr',
      ThermalSeason.jul: 'jul',
      ThermalSeason.oct: 'oct',
    };
    const timeCodes = {
      ThermalTimeOfDay.all: 'all',
      ThermalTimeOfDay.morning: '04',
      ThermalTimeOfDay.midday: '07',
      ThermalTimeOfDay.evening: '10',
    };

    test('all 5 x 4 concrete combinations map to KK7 layer ids', () {
      final ids = <String>{};
      for (final s in seasonCodes.entries) {
        for (final t in timeCodes.entries) {
          final v = ThermalVariant(s.key, t.key);
          expect(v.layerId, 'thermals_${s.value}_${t.value}');
          expect(ThermalVariant.tryParseKey(v.key), v);
          ids.add(v.layerId);
        }
      }
      expect(ids, hasLength(20));
    });

    test('auto settings resolve to concrete variants for all combinations', () {
      final now = DateTime.utc(2026, 7, 15, 10);
      const pos = LatLng(47.2692, 11.4041);
      for (final s in ThermalSeason.values) {
        for (final t in ThermalTimeOfDay.values) {
          final v = ThermalVariantResolver.resolve(
            season: s,
            timeOfDay: t,
            now: now,
            gpsFix: pos,
          );
          expect(v.season, isNot(ThermalSeason.auto));
          expect(v.timeOfDay, isNot(ThermalTimeOfDay.auto));
          if (s != ThermalSeason.auto) expect(v.season, s);
          if (t != ThermalTimeOfDay.auto) expect(v.timeOfDay, t);
        }
      }
    });

    test('auto has no KK7 code', () {
      expect(() => ThermalSeason.auto.kk7Code, throwsStateError);
      expect(() => ThermalTimeOfDay.auto.kk7Code, throwsStateError);
      expect(ThermalVariant.tryParseKey('foo_07'), isNull);
      expect(ThermalVariant.tryParseKey('jul'), isNull);
    });
  });

  group('SunriseCalculator', () {
    // Reference values from the astral library (NOAA algorithm).
    void expectSunrise(
      double lat,
      double lon,
      int y,
      int m,
      int d,
      DateTime expectedUtc,
    ) {
      final r = SunriseCalculator.sunrise(
        year: y,
        month: m,
        day: d,
        latitude: lat,
        longitude: lon,
      );
      expect(r, isA<SunriseAt>());
      final diff = (r as SunriseAt).utc.difference(expectedUtc).inSeconds.abs();
      expect(diff, lessThanOrEqualTo(120), reason: 'got ${r.utc}');
    }

    test('Innsbruck solstices and equinox within 2 minutes', () {
      expectSunrise(
        47.2692,
        11.4041,
        2026,
        6,
        21,
        DateTime.utc(2026, 6, 21, 3, 18, 24),
      );
      expectSunrise(
        47.2692,
        11.4041,
        2026,
        12,
        21,
        DateTime.utc(2026, 12, 21, 6, 58, 36),
      );
      expectSunrise(
        47.2692,
        11.4041,
        2026,
        3,
        20,
        DateTime.utc(2026, 3, 20, 5, 17, 55),
      );
    });

    test('eastern longitude yields the local-date sunrise (Sydney)', () {
      // Sydney sunrise on local 21 June is 20 June ~21:00 UTC.
      expectSunrise(
        -33.8688,
        151.2093,
        2026,
        6,
        21,
        DateTime.utc(2026, 6, 20, 21, 0, 24),
      );
    });

    test('polar day and polar night', () {
      expect(
        SunriseCalculator.sunrise(
          year: 2026,
          month: 6,
          day: 21,
          latitude: 78.2,
          longitude: 15.6,
        ),
        isA<PolarDay>(),
      );
      expect(
        SunriseCalculator.sunrise(
          year: 2026,
          month: 12,
          day: 21,
          latitude: 78.2,
          longitude: 15.6,
        ),
        isA<PolarNight>(),
      );
    });
  });

  group('ThermalVariantResolver season', () {
    test('month to meteorological season bin', () {
      const expected = {
        1: ThermalSeason.jan,
        2: ThermalSeason.jan,
        3: ThermalSeason.apr,
        4: ThermalSeason.apr,
        5: ThermalSeason.apr,
        6: ThermalSeason.jul,
        7: ThermalSeason.jul,
        8: ThermalSeason.jul,
        9: ThermalSeason.oct,
        10: ThermalSeason.oct,
        11: ThermalSeason.oct,
        12: ThermalSeason.jan,
      };
      expected.forEach((month, season) {
        expect(ThermalVariantResolver.seasonForMonth(month), season);
      });
    });

    test('Scenario: season in mid-summer', () {
      final v = ThermalVariantResolver.resolve(
        season: ThermalSeason.auto,
        timeOfDay: ThermalTimeOfDay.all,
        now: DateTime(2026, 7, 15, 12),
      );
      expect(v.season, ThermalSeason.jul);
    });

    test('Scenario: season boundary 28 Feb -> 1 Mar', () {
      ThermalSeason at(DateTime d) => ThermalVariantResolver.resolve(
        season: ThermalSeason.auto,
        timeOfDay: ThermalTimeOfDay.all,
        now: d,
      ).season;
      expect(at(DateTime(2026, 2, 28, 23, 59)), ThermalSeason.jan);
      expect(at(DateTime(2026, 3, 1, 0, 1)), ThermalSeason.apr);
    });

    test('next season and last-month detection', () {
      expect(
        ThermalVariantResolver.nextSeason(ThermalSeason.oct),
        ThermalSeason.jan,
      );
      expect(
        ThermalVariantResolver.nextSeason(ThermalSeason.jul),
        ThermalSeason.oct,
      );
      expect(
        [
          for (var m = 1; m <= 12; m++)
            if (ThermalVariantResolver.isLastMonthOfSeason(m)) m,
        ],
        [2, 5, 8, 11],
      );
    });
  });

  group('ThermalVariantResolver time of day', () {
    test('bin thresholds', () {
      ThermalTimeOfDay bin(double h) =>
          ThermalVariantResolver.timeOfDayForHoursSinceSunrise(h);
      expect(bin(-1), ThermalTimeOfDay.morning); // before sunrise
      expect(bin(0), ThermalTimeOfDay.morning);
      expect(bin(5.99), ThermalTimeOfDay.morning);
      expect(bin(6), ThermalTimeOfDay.midday);
      expect(bin(8.99), ThermalTimeOfDay.midday);
      expect(bin(9), ThermalTimeOfDay.evening);
      expect(bin(15), ThermalTimeOfDay.evening);
    });

    // Krippenstein on 20 March 2026: sunrise ~05:08:47 UTC.
    const krippenstein = LatLng(47.525, 13.685);
    ThermalTimeOfDay at(DateTime utc, {LatLng? fix = krippenstein}) =>
        ThermalVariantResolver.resolve(
          season: ThermalSeason.auto,
          timeOfDay: ThermalTimeOfDay.auto,
          now: utc,
          gpsFix: fix,
        ).timeOfDay;

    test('Scenario: morning, midday and evening flights', () {
      // sunrise + 4.3 h
      expect(at(DateTime.utc(2026, 3, 20, 9, 30)), ThermalTimeOfDay.morning);
      // sunrise + 7.3 h
      expect(at(DateTime.utc(2026, 3, 20, 12, 30)), ThermalTimeOfDay.midday);
      // sunrise + 9.4 h
      expect(at(DateTime.utc(2026, 3, 20, 14, 30)), ThermalTimeOfDay.evening);
      // before sunrise
      expect(at(DateTime.utc(2026, 3, 20, 4, 0)), ThermalTimeOfDay.morning);
    });

    test('Scenario: no GPS fix uses last known position, then map center', () {
      final now = DateTime.utc(2026, 3, 20, 12, 30);
      final withLastKnown = ThermalVariantResolver.resolve(
        season: ThermalSeason.auto,
        timeOfDay: ThermalTimeOfDay.auto,
        now: now,
        lastKnownPosition: krippenstein,
      );
      expect(withLastKnown.timeOfDay, ThermalTimeOfDay.midday);
      final withCenter = ThermalVariantResolver.resolve(
        season: ThermalSeason.auto,
        timeOfDay: ThermalTimeOfDay.auto,
        now: now,
        mapCenter: krippenstein,
      );
      expect(withCenter.timeOfDay, ThermalTimeOfDay.midday);
      expect(
        ThermalVariantResolver.effectivePosition(
          gpsFix: null,
          lastKnownPosition: const LatLng(1, 1),
          mapCenter: const LatLng(2, 2),
        ),
        const LatLng(1, 1),
      );
      // No position at all still yields a displayable variant.
      final none = ThermalVariantResolver.resolve(
        season: ThermalSeason.auto,
        timeOfDay: ThermalTimeOfDay.auto,
        now: now,
      );
      expect(none.timeOfDay, ThermalTimeOfDay.all);
    });

    test('polar day falls back to all', () {
      expect(
        at(DateTime.utc(2026, 6, 21, 12), fix: const LatLng(78.2, 15.6)),
        ThermalTimeOfDay.all,
      );
    });

    test('Scenario: manual variant selection is used unchanged', () {
      final v = ThermalVariantResolver.resolve(
        season: ThermalSeason.jul,
        timeOfDay: ThermalTimeOfDay.morning,
        now: DateTime.utc(2026, 12, 1, 18),
        gpsFix: krippenstein,
      );
      expect(v.layerId, 'thermals_jul_04');
      final all = ThermalVariantResolver.resolve(
        season: ThermalSeason.all,
        timeOfDay: ThermalTimeOfDay.all,
        now: DateTime.utc(2026, 12, 1, 18),
      );
      expect(all.layerId, 'thermals_all_all');
    });
  });
}
