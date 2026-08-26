import 'package:brandyfly/models/flight_model.dart';
import 'package:brandyfly/models/flight_settings.dart';
import 'package:brandyfly/models/ui_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FlightPoint Serialization & Behavior', () {
    test('roundtrip serialization to/from JSON matches', () {
      final now = DateTime.utc(2026, 8, 20, 10, 30, 0);
      final point = FlightPoint(
        timestamp: now,
        latitude: 47.5246,
        longitude: 13.6917,
        altitude: 1850.5,
        gnssAltitude: 1860.2,
        vario: 2.3,
        speed: 38.5,
        heading: 145.0,
        hag: 450.0,
      );

      final json = point.toJson();
      final restored = FlightPoint.fromJson(json);

      expect(restored.timestamp, point.timestamp);
      expect(restored.latitude, point.latitude);
      expect(restored.longitude, point.longitude);
      expect(restored.altitude, point.altitude);
      expect(restored.gnssAltitude, point.gnssAltitude);
      expect(restored.vario, point.vario);
      expect(restored.speed, point.speed);
      expect(restored.heading, point.heading);
      expect(restored.hag, point.hag);
    });

    test('fromJson handles null optional fields gracefully', () {
      final json = {
        'timestamp': '2026-08-20T10:30:00.000Z',
        'latitude': 47.0,
        'longitude': 13.0,
        'altitude': 1500.0,
      };
      final point = FlightPoint.fromJson(json);

      expect(point.gnssAltitude, isNull);
      expect(point.vario, 0.0);
      expect(point.speed, 0.0);
      expect(point.heading, 0.0);
      expect(point.hag, isNull);
    });
  });

  group('FlightStatistics Serialization & Behavior', () {
    test('roundtrip serialization and empty default', () {
      const stats = FlightStatistics(
        duration: Duration(minutes: 45, seconds: 12),
        maxAltitude: 2350.0,
        minAltitude: 850.0,
        maxClimbRate: 4.2,
        maxSinkRate: -2.8,
        totalDistanceKm: 28.4,
        averageSpeedKmh: 36.2,
        averageGlideRatio: 8.5,
      );

      final json = stats.toJson();
      final restored = FlightStatistics.fromJson(json);

      expect(restored.duration, stats.duration);
      expect(restored.maxAltitude, stats.maxAltitude);
      expect(restored.minAltitude, stats.minAltitude);
      expect(restored.maxClimbRate, stats.maxClimbRate);
      expect(restored.maxSinkRate, stats.maxSinkRate);
      expect(restored.totalDistanceKm, stats.totalDistanceKm);
      expect(restored.averageSpeedKmh, stats.averageSpeedKmh);
      expect(restored.averageGlideRatio, stats.averageGlideRatio);

      final empty = FlightStatistics.empty();
      expect(empty.duration, Duration.zero);
      expect(empty.maxAltitude, 0.0);
    });
  });

  group('FlightModel Serialization & copyWith', () {
    test('roundtrip serialization and copyWith updates', () {
      final flight = FlightModel(
        id: 'flight_12345',
        title: 'Morning Flight',
        date: DateTime.utc(2026, 8, 20, 8, 0, 0),
        pilotName: 'Pilot Test',
        gliderType: 'Ozone Rush',
        siteName: 'Schmittenhoehe',
        category: FlightCategory.plannedFlights,
        uploadStatus: UploadStatus.queued,
        points: [
          FlightPoint(
            timestamp: DateTime.utc(2026, 8, 20, 8, 0, 0),
            latitude: 47.3,
            longitude: 12.8,
            altitude: 2000.0,
          ),
        ],
        statistics: const FlightStatistics(
          duration: Duration(minutes: 10),
          maxAltitude: 2000.0,
          minAltitude: 1500.0,
          maxClimbRate: 2.0,
          maxSinkRate: -1.0,
          totalDistanceKm: 5.0,
          averageSpeedKmh: 30.0,
          averageGlideRatio: 7.0,
        ),
        rawIgcContent: 'AXFH001',
        isSampleFlight: false,
      );

      final json = flight.toJson();
      final restored = FlightModel.fromJson(json);

      expect(restored.id, flight.id);
      expect(restored.title, flight.title);
      expect(restored.pilotName, flight.pilotName);
      expect(restored.gliderType, flight.gliderType);
      expect(restored.siteName, flight.siteName);
      expect(restored.category, FlightCategory.plannedFlights);
      expect(restored.uploadStatus, UploadStatus.queued);
      expect(restored.points.length, 1);
      expect(restored.rawIgcContent, 'AXFH001');

      final modified = flight.copyWith(
        title: 'Updated Title',
        uploadStatus: UploadStatus.uploaded,
      );
      expect(modified.title, 'Updated Title');
      expect(modified.uploadStatus, UploadStatus.uploaded);
      expect(modified.id, flight.id);
    });
  });

  group('FlightSettings Serialization & Defaults', () {
    test('roundtrip serialization with custom values', () {
      const settings = FlightSettings(
        takeoffSpeedThresholdKmh: 14.5,
        takeoffVarioThresholdMs: 1.2,
        takeoffSustainedDurationSeconds: 6,
        takeoffHagThresholdM: 20.0,
        preTakeoffBufferDurationSeconds: 20,
        landingSpeedThresholdKmh: 6.0,
        landingVarioThresholdMs: 0.3,
        landingSettlingDurationSeconds: 25,
        autoUploadToXContest: true,
        xcontestUsername: 'pilot1',
        xcontestPassword: 'secretpassword',
      );

      final json = settings.toJson();
      final restored = FlightSettings.fromJson(json);

      expect(restored.takeoffSpeedThresholdKmh, 14.5);
      expect(restored.takeoffVarioThresholdMs, 1.2);
      expect(restored.takeoffSustainedDurationSeconds, 6);
      expect(restored.autoUploadToXContest, isTrue);
      expect(restored.xcontestUsername, 'pilot1');
      expect(restored.xcontestPassword, 'secretpassword');

      final copied = settings.copyWith(xcontestUsername: 'pilot2');
      expect(copied.xcontestUsername, 'pilot2');
      expect(copied.takeoffSpeedThresholdKmh, 14.5);
    });
  });

  group('UIConfig JSON Serialization', () {
    test('encode and decode roundtrip matches default config', () {
      final config = UIConfig.defaultConfig();
      final jsonString = config.encodeJson();
      final restored = UIConfig.decodeJson(jsonString);

      expect(restored.navBarStyle, config.navBarStyle);
      expect(restored.thermalingStyle, config.thermalingStyle);
      expect(restored.settingsStyle, config.settingsStyle);
      expect(restored.screens.length, config.screens.length);
      expect(restored.activeScreenId, config.activeScreenId);
    });

    test('UIConfig copyWith overrides individual fields', () {
      final config = UIConfig.defaultConfig();
      final modified = config.copyWith(
        navBarStyle: NavBarStyle.floatingPill,
        activeScreenId: 'custom_screen',
      );

      expect(modified.navBarStyle, NavBarStyle.floatingPill);
      expect(modified.activeScreenId, 'custom_screen');
    });
  });
}
