import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/flight_model.dart';
import 'igc_parser_service.dart';

class FlightStorageService extends ChangeNotifier {
  FlightStorageService({
    SharedPreferences? preferences,
    IGCParserService? igcParser,
  })  : _prefs = preferences,
        _igcParser = igcParser ?? const IGCParserService();

  static const String _storageKey = 'brandyfly_flights_data';
  static const String _initializedKey = 'brandyfly_sample_flight_initialized';
  static const String sampleFlightAssetPath = 'assets/sample_flights/Krippenstein-Aussee.IGC';

  final SharedPreferences? _prefs;
  final IGCParserService _igcParser;

  final Map<String, FlightModel> _flightsMap = {};

  List<FlightModel> get flights =>
      _flightsMap.values.toList()..sort((a, b) => b.date.compareTo(a.date));

  List<FlightModel> get myFlights =>
      flights.where((f) => f.category == FlightCategory.myFlights).toList();

  List<FlightModel> get plannedFlights =>
      flights.where((f) => f.category == FlightCategory.plannedFlights).toList();

  static Future<FlightStorageService> init({
    SharedPreferences? preferences,
    IGCParserService? igcParser,
  }) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    final service = FlightStorageService(
      preferences: prefs,
      igcParser: igcParser,
    );
    await service._loadFromStorage();
    await service.initializeSampleFlight();
    return service;
  }

  Future<void> _loadFromStorage() async {
    if (_prefs == null) return;
    final jsonString = _prefs.getString(_storageKey);
    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        final list = jsonDecode(jsonString) as List<dynamic>;
        _flightsMap.clear();
        for (final item in list) {
          final flight = FlightModel.fromJson(item as Map<String, dynamic>);
          _flightsMap[flight.id] = flight;
        }
      } catch (e) {
        debugPrint('Error loading flights from storage: $e');
      }
    }
  }

  Future<void> _persistToStorage() async {
    if (_prefs == null) return;
    try {
      final list = _flightsMap.values.map((f) => f.toJson()).toList();
      await _prefs.setString(_storageKey, jsonEncode(list));
    } catch (e) {
      debugPrint('Error saving flights to storage: $e');
    }
  }

  Future<void> saveFlight(FlightModel flight) async {
    _flightsMap[flight.id] = flight;
    await _persistToStorage();
    notifyListeners();
  }

  Future<void> deleteFlight(String flightId) async {
    _flightsMap.remove(flightId);
    await _persistToStorage();
    notifyListeners();
  }

  Future<void> renameFlight(String flightId, String newTitle) async {
    final flight = _flightsMap[flightId];
    if (flight != null) {
      _flightsMap[flightId] = flight.copyWith(title: newTitle);
      await _persistToStorage();
      notifyListeners();
    }
  }

  Future<void> updateFlightCategory(String flightId, FlightCategory category) async {
    final flight = _flightsMap[flightId];
    if (flight != null) {
      _flightsMap[flightId] = flight.copyWith(category: category);
      await _persistToStorage();
      notifyListeners();
    }
  }

  Future<void> updateUploadStatus(String flightId, UploadStatus status) async {
    final flight = _flightsMap[flightId];
    if (flight != null) {
      _flightsMap[flightId] = flight.copyWith(uploadStatus: status);
      await _persistToStorage();
      notifyListeners();
    }
  }

  Future<void> initializeSampleFlight({String? assetIgcContent}) async {
    final existingSample = _flightsMap['sample_krippenstein_aussee'];
    final needsRefresh = existingSample == null ||
        (existingSample.points.isNotEmpty &&
            existingSample.statistics.maxClimbRate == 0.3 &&
            existingSample.statistics.maxSinkRate == 0.3);

    if (_prefs != null && _prefs.getBool(_initializedKey) == true && !needsRefresh) {
      return;
    }
    await restoreSampleFlight(assetIgcContent: assetIgcContent);
    if (_prefs != null) {
      await _prefs.setBool(_initializedKey, true);
    }
  }

  Future<void> restoreSampleFlight({String? assetIgcContent}) async {
    String igcData = assetIgcContent ?? '';
    if (igcData.isEmpty) {
      try {
        igcData = await rootBundle.loadString(sampleFlightAssetPath);
      } catch (e) {
        debugPrint('Could not load bundled asset $sampleFlightAssetPath: $e');
      }
    }

    if (igcData.isNotEmpty) {
      final sample = _igcParser
          .parseIgc(
            igcData,
            id: 'sample_krippenstein_aussee',
            defaultTitle: 'Krippenstein - Bad Aussee (Sample)',
          )
          .copyWith(isSampleFlight: true, category: FlightCategory.myFlights);
      _flightsMap[sample.id] = sample;
      await _persistToStorage();
      notifyListeners();
    }
  }

  Future<FlightModel> importFlight(
    String fileContent, {
    required String filename,
    required FlightCategory category,
  }) async {
    FlightModel flight;
    if (fileContent.trim().startsWith('{')) {
      // JSON format
      final jsonMap = jsonDecode(fileContent) as Map<String, dynamic>;
      flight = FlightModel.fromJson(jsonMap).copyWith(
        id: 'flight_${DateTime.now().millisecondsSinceEpoch}',
        category: category,
      );
    } else {
      // IGC format
      final titleWithoutExt = filename.replaceAll(RegExp(r'\.(igc|IGC|json)$'), '');
      flight = _igcParser
          .parseIgc(
            fileContent,
            id: 'flight_${DateTime.now().millisecondsSinceEpoch}',
            defaultTitle: titleWithoutExt,
          )
          .copyWith(category: category);
    }

    await saveFlight(flight);
    return flight;
  }

  String exportAsIgc(FlightModel flight) {
    if (flight.rawIgcContent != null && flight.rawIgcContent!.isNotEmpty) {
      return flight.rawIgcContent!;
    }
    return _igcParser.generateIgc(flight);
  }

  String exportAsJson(FlightModel flight) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(flight.toJson());
  }

  String exportAsCsv(FlightModel flight) {
    final buffer = StringBuffer();
    buffer.writeln('timestamp,latitude,longitude,altitude,gnssAltitude,vario,speed,heading,hag');
    for (final p in flight.points) {
      buffer.writeln(
        '${p.timestamp.toIso8601String()},${p.latitude},${p.longitude},${p.altitude},${p.gnssAltitude ?? ''},${p.vario},${p.speed},${p.heading},${p.hag ?? ''}',
      );
    }
    return buffer.toString();
  }

  List<FlightModel> searchFlights(String query, {FlightCategory? category}) {
    var list = category == null
        ? flights
        : (category == FlightCategory.myFlights ? myFlights : plannedFlights);
    if (query.trim().isEmpty) return list;

    final q = query.toLowerCase().trim();
    return list.where((f) {
      return f.title.toLowerCase().contains(q) ||
          f.pilotName.toLowerCase().contains(q) ||
          f.siteName.toLowerCase().contains(q) ||
          f.gliderType.toLowerCase().contains(q) ||
          f.date.toIso8601String().contains(q);
    }).toList();
  }
}
