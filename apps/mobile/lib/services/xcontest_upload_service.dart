import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/flight_model.dart';
import '../models/flight_settings.dart';
import 'flight_storage_service.dart';

class XContestUploadService extends ChangeNotifier {
  XContestUploadService({
    required this.storageService,
    FlightSettings? settings,
    this.isOnline = true,
  })  : _settings = settings ?? const FlightSettings();

  final FlightStorageService storageService;
  FlightSettings _settings;
  bool isOnline;
  bool _isSyncing = false;

  bool get isSyncing => _isSyncing;

  List<FlightModel> get queuedFlights => storageService.flights
      .where((f) => f.uploadStatus == UploadStatus.queued)
      .toList();

  int get queuedCount => queuedFlights.length;

  void updateSettings(FlightSettings settings) {
    _settings = settings;
    notifyListeners();
  }

  void setOnlineStatus(bool online) {
    if (isOnline != online) {
      isOnline = online;
      notifyListeners();
      if (isOnline) {
        syncQueuedFlights();
      }
    }
  }

  Future<bool> uploadFlight(FlightModel flight) async {
    // Check credentials
    if (_settings.xcontestUsername.isEmpty) {
      debugPrint('XContest upload skipped: No username configured');
      await storageService.updateUploadStatus(flight.id, UploadStatus.failed);
      return false;
    }

    if (!isOnline) {
      debugPrint('XContest upload queued: Device offline');
      await storageService.updateUploadStatus(flight.id, UploadStatus.queued);
      notifyListeners();
      return false;
    }

    await storageService.updateUploadStatus(flight.id, UploadStatus.uploading);
    notifyListeners();

    try {
      // Simulate network transmission delay for XContest upload
      await Future<void>.delayed(const Duration(milliseconds: 300));
      // Succeeded!
      await storageService.updateUploadStatus(flight.id, UploadStatus.uploaded);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('XContest upload failed: $e');
      await storageService.updateUploadStatus(flight.id, UploadStatus.failed);
      notifyListeners();
      return false;
    }
  }

  Future<void> retryUpload(FlightModel flight) async {
    await uploadFlight(flight);
  }

  Future<void> syncQueuedFlights() async {
    if (_isSyncing || !isOnline) return;
    _isSyncing = true;
    notifyListeners();

    final queue = List<FlightModel>.from(queuedFlights);
    for (final flight in queue) {
      await uploadFlight(flight);
    }

    _isSyncing = false;
    notifyListeners();
  }
}
