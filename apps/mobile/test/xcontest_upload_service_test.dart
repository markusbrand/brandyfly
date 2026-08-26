import 'package:brandyfly/models/flight_model.dart';
import 'package:brandyfly/models/flight_settings.dart';
import 'package:brandyfly/services/flight_storage_service.dart';
import 'package:brandyfly/services/xcontest_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('XContestUploadService Tests', () {
    late FlightStorageService storage;
    late FlightModel testFlight;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storage = FlightStorageService(preferences: prefs);

      testFlight = FlightModel(
        id: 'flight_1',
        title: 'Test Flight 1',
        date: DateTime.utc(2026, 8, 20, 10, 0, 0),
        uploadStatus: UploadStatus.notUploaded,
      );
      await storage.saveFlight(testFlight);
    });

    test('Fails upload if XContest username is not configured', () async {
      final uploadService = XContestUploadService(
        storageService: storage,
        settings: const FlightSettings(xcontestUsername: ''),
      );

      final result = await uploadService.uploadFlight(testFlight);
      expect(result, isFalse);
      expect(storage.flights.first.uploadStatus, UploadStatus.failed);
    });

    test('Queues flight when offline and syncs automatically when online', () async {
      final uploadService = XContestUploadService(
        storageService: storage,
        settings: const FlightSettings(
          xcontestUsername: 'markus_pilot',
          xcontestPassword: 'secret_token',
        ),
        isOnline: false,
      );

      // Offline upload attempt
      final result = await uploadService.uploadFlight(testFlight);
      expect(result, isFalse);
      expect(storage.flights.first.uploadStatus, UploadStatus.queued);
      expect(uploadService.queuedCount, 1);

      // Network becomes available
      uploadService.setOnlineStatus(true);
      await Future<void>.delayed(const Duration(milliseconds: 500));

      expect(storage.flights.first.uploadStatus, UploadStatus.uploaded);
      expect(uploadService.queuedCount, 0);
    });

    test('Manual retry triggers re-upload', () async {
      final uploadService = XContestUploadService(
        storageService: storage,
        settings: const FlightSettings(
          xcontestUsername: 'markus_pilot',
          xcontestPassword: 'secret_token',
        ),
        isOnline: true,
      );

      await uploadService.retryUpload(testFlight);
      expect(storage.flights.first.uploadStatus, UploadStatus.uploaded);
    });
  });
}
