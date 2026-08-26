import 'dart:convert';
import 'package:brandyfly/models/flight_model.dart';
import 'package:brandyfly/services/flight_storage_service.dart';
import 'package:brandyfly/services/igc_parser_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const sampleIgcContent = '''AXFH000
HFDTE150826
HFPLTPILOT:Markus Brandstätter
HFGTYGLIDERTYPE:Ozone Delta 5
HFDTM100GPSDATUM:WGS84
HFSITSITE:Krippenstein,AT
I043638FXA3941VXA4244GSP4547HDT
B1023034731478N01341504EA0209802098004003004306155
B1023044731478N01341504EA0209802098004003004306167
B1023054731479N01341503EA0209802098004003000306149
B1023064731479N01341503EA0209802098004003000306185
G00000000000000000000000000000000
''';

void main() {
  group('IGCParserService & FlightStorageService Tests', () {
    const parser = IGCParserService();

    test('Parses standard IGC content with headers and B-records', () {
      final flight = parser.parseIgc(sampleIgcContent);
      expect(flight.pilotName, 'Markus Brandstätter');
      expect(flight.gliderType, 'Ozone Delta 5');
      expect(flight.siteName, 'Krippenstein,AT');
      expect(flight.points.length, 4);
      expect(flight.points.first.altitude, 2098.0);
      expect(flight.points.first.latitude, closeTo(47.5246, 0.001));
      expect(flight.points.first.longitude, closeTo(13.6917, 0.001));
    });

    test('Generates valid FAI IGC compliant string and preserves fidelity', () {
      final flight = parser.parseIgc(sampleIgcContent);
      final generatedIgc = parser.generateIgc(flight);

      expect(generatedIgc, contains('HFDTE150826'));
      expect(generatedIgc, contains('HFPLTPILOT:Markus Brandstätter'));
      expect(generatedIgc, contains('B102303'));
      expect(generatedIgc, contains('G00000000000000000000000000000000'));

      // Parse generated IGC back
      final reparsed = parser.parseIgc(generatedIgc);
      expect(reparsed.points.length, flight.points.length);
      expect(reparsed.pilotName, flight.pilotName);
      expect(reparsed.points.first.altitude, flight.points.first.altitude);
    });

    test('Exports flight as JSON and CSV accurately', () {
      final storage = FlightStorageService();
      final flight = parser.parseIgc(sampleIgcContent);

      final jsonStr = storage.exportAsJson(flight);
      final decodedJson = jsonDecode(jsonStr) as Map<String, dynamic>;
      expect(decodedJson['pilotName'], 'Markus Brandstätter');
      expect(decodedJson['points'], isList);

      final csvStr = storage.exportAsCsv(flight);
      expect(csvStr, startsWith('timestamp,latitude,longitude'));
      expect(csvStr.split('\n').length, greaterThanOrEqualTo(5));
    });

    test('FlightStorageService handles CRUD, categories, search, and restore', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = FlightStorageService(preferences: prefs);

      // Seed sample flight
      await storage.restoreSampleFlight(assetIgcContent: sampleIgcContent);
      expect(storage.flights.length, 1);
      expect(storage.flights.first.isSampleFlight, isTrue);
      expect(storage.myFlights.length, 1);
      expect(storage.plannedFlights.length, 0);

      // Search
      final searchResults = storage.searchFlights('Krippenstein');
      expect(searchResults.length, 1);
      final searchEmpty = storage.searchFlights('NonExistentSite');
      expect(searchEmpty.length, 0);

      // Rename
      final sampleId = storage.flights.first.id;
      await storage.renameFlight(sampleId, 'My Epic Flight');
      expect(storage.flights.first.title, 'My Epic Flight');

      // Update category
      await storage.updateFlightCategory(sampleId, FlightCategory.plannedFlights);
      expect(storage.myFlights.length, 0);
      expect(storage.plannedFlights.length, 1);

      // Delete
      await storage.deleteFlight(sampleId);
      expect(storage.flights.length, 0);

      // Restore sample flight again
      await storage.restoreSampleFlight(assetIgcContent: sampleIgcContent);
      expect(storage.flights.length, 1);
    });

    test('Imports manual flight tracks from JSON and IGC strings', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = FlightStorageService(preferences: prefs);

      // Import IGC
      final importedIgc = await storage.importFlight(
        sampleIgcContent,
        filename: 'krippenstein.igc',
        category: FlightCategory.myFlights,
      );
      expect(importedIgc.points.length, 4);
      expect(storage.myFlights.length, 1);

      // Import JSON
      final jsonPayload = storage.exportAsJson(importedIgc);
      final importedJson = await storage.importFlight(
        jsonPayload,
        filename: 'planned_flight.json',
        category: FlightCategory.plannedFlights,
      );
      expect(importedJson.category, FlightCategory.plannedFlights);
      expect(storage.plannedFlights.length, 1);
      expect(storage.flights.length, 2);
    });

    test('Parses Southern and Western hemisphere coordinates accurately', () {
      const southernWesternIgc = '''AXFH001
HFDTE200826
HFPLTPILOT:Southern Pilot
I00
B1200002254321S04312345WA0050000520
''';
      final flight = parser.parseIgc(southernWesternIgc);
      expect(flight.points.length, 1);
      final pt = flight.points.first;
      expect(pt.latitude, lessThan(0)); // South
      expect(pt.longitude, lessThan(0)); // West
      expect(pt.altitude, 500.0);
    });

    test('Calculates distance and bearing correctly between coordinates', () {
      // Distance between Vienna (48.2082 N, 16.3738 E) and Graz (47.0707 N, 15.4395 E) is ~145 km
      final dist = IGCParserService.calculateDistanceKm(48.2082, 16.3738, 47.0707, 15.4395);
      expect(dist, closeTo(145.0, 10.0));

      final bearing = IGCParserService.calculateBearing(48.2082, 16.3738, 47.0707, 15.4395);
      expect(bearing, greaterThan(180.0)); // Bearing southwest
      expect(bearing, lessThan(270.0));
    });

    test('Handles edge cases in computeStatistics gracefully', () {
      final emptyStats = IGCParserService.computeStatistics([]);
      expect(emptyStats.duration, Duration.zero);
      expect(emptyStats.maxAltitude, 0.0);

      final singlePointStats = IGCParserService.computeStatistics([
        FlightPoint(
          timestamp: DateTime.utc(2026, 8, 20, 10, 0, 0),
          latitude: 47.0,
          longitude: 13.0,
          altitude: 1500.0,
        ),
      ]);
      expect(singlePointStats.duration, Duration.zero);
      expect(singlePointStats.maxAltitude, 1500.0);
      expect(singlePointStats.minAltitude, 1500.0);
    });
  });
}
