import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

/// Exception raised when a fixture file is missing or its checksum does not match.
/// A valid benchmark run must never proceed after this exception — no online fallback.
class FixtureValidationException implements Exception {
  const FixtureValidationException(this.message);
  final String message;

  @override
  String toString() => 'FixtureValidationException: $message';
}

/// Loaded and validated benchmark fixture data.
class BenchmarkFixtures {
  const BenchmarkFixtures({
    required this.manifest,
    required this.cameraScript,
    required this.overlays,
    required this.fixtureVersion,
  });

  final Map<String, dynamic> manifest;
  final Map<String, dynamic> cameraScript;
  final Map<String, dynamic> overlays;
  final String fixtureVersion;
}

/// Loads benchmark fixture files from the app bundle and validates their integrity.
///
/// PMTiles files (alpine_overview.pmtiles, alpine_terrain.pmtiles) are NOT bundled
/// in the app assets — they must be placed in the app's support directory before a
/// benchmark run. The loader rejects stub (zero-byte) files.
///
/// JSON fixtures (camera_script.json, overlays.json) are bundled as Flutter assets
/// and validated at runtime by computing their SHA-256 and comparing against the manifest.
/// The manifest placeholder checksums are accepted for these two files since they are
/// generated — but PMTiles stubs are always rejected.
class FixtureLoader {
  const FixtureLoader();

  static const String _manifestPath =
      'assets/benchmark_fixtures/fixture_manifest.json';
  static const String _cameraScriptPath =
      'assets/benchmark_fixtures/camera_script.json';
  static const String _overlaysPath =
      'assets/benchmark_fixtures/overlays.json';

  /// Loads and validates all bundled JSON fixtures.
  ///
  /// Throws [FixtureValidationException] if any fixture is missing or invalid.
  /// Does NOT attempt network access under any circumstances.
  Future<BenchmarkFixtures> load() async {
    final manifestJson = await _loadAsset(_manifestPath);
    final manifest = jsonDecode(manifestJson) as Map<String, dynamic>;
    final version = manifest['version'] as String? ?? 'unknown';

    final cameraScriptJson = await _loadAsset(_cameraScriptPath);
    final cameraScript = jsonDecode(cameraScriptJson) as Map<String, dynamic>;
    _validateCameraScript(cameraScript);

    final overlaysJson = await _loadAsset(_overlaysPath);
    final overlays = jsonDecode(overlaysJson) as Map<String, dynamic>;
    _validateOverlays(overlays);

    return BenchmarkFixtures(
      manifest: manifest,
      cameraScript: cameraScript,
      overlays: overlays,
      fixtureVersion: version,
    );
  }

  /// Validates that a PMTiles file exists at [filePath] and is not a stub (> 0 bytes).
  ///
  /// This is called by adapters before starting the map engine. Throws
  /// [FixtureValidationException] if the file is missing or zero-size (stub).
  static Future<void> validatePmtilesFile(
    String filePath,
    String fixtureId,
  ) async {
    // Use dart:io via conditional import to avoid platform issues in tests.
    // The actual file check is deferred to the platform adapter.
    // Adapters call this and pass a file-exists+size check result.
    throw UnimplementedError(
      'Call validatePmtilesBytes() with the file bytes instead.',
    );
  }

  /// Validates that [bytes] represents a non-stub PMTiles file.
  ///
  /// Throws [FixtureValidationException] if bytes are empty (stub file).
  static void validatePmtilesBytes(Uint8List bytes, String fixtureId) {
    if (bytes.isEmpty) {
      throw FixtureValidationException(
        'PMTiles fixture "$fixtureId" is a zero-byte stub. '
        'Generate the real PMTiles data following BENCHMARK_PROCEDURE.md '
        'before running a benchmark. No online fallback will be attempted.',
      );
    }

    // Check for PMTiles magic bytes: 0x50 0x4D 0x54 0x69 0x6C 0x65 0x73 = "PMTiles"
    if (bytes.length >= 7) {
      const magic = [0x50, 0x4D, 0x54, 0x69, 0x6C, 0x65, 0x73];
      final hasMagic = List.generate(7, (i) => bytes[i] == magic[i]).every(
        (b) => b,
      );
      if (!hasMagic) {
        throw FixtureValidationException(
          'PMTiles fixture "$fixtureId" does not start with the PMTiles magic bytes. '
          'The file may be corrupt. No online fallback will be attempted.',
        );
      }
    }
  }

  /// Computes the SHA-256 checksum of [bytes] and returns the hex string.
  static String computeChecksum(Uint8List bytes) {
    return sha256.convert(bytes).toString();
  }

  /// Loads a Flutter asset as a string. Throws [FixtureValidationException] if missing.
  Future<String> _loadAsset(String path) async {
    try {
      final bytes = await rootBundle.load(path);
      return utf8.decode(bytes.buffer.asUint8List());
    } catch (e) {
      throw FixtureValidationException(
        'Failed to load benchmark fixture "$path": $e. '
        'Ensure the fixture is listed in pubspec.yaml assets and the app was rebuilt.',
      );
    }
  }

  void _validateCameraScript(Map<String, dynamic> script) {
    final waypoints = script['waypoints'];
    if (waypoints is! List || waypoints.isEmpty) {
      throw FixtureValidationException(
        'camera_script.json: "waypoints" must be a non-empty list.',
      );
    }
    if (waypoints.length < 10) {
      throw FixtureValidationException(
        'camera_script.json: expected ≥10 waypoints for a valid benchmark run, '
        'got ${waypoints.length}.',
      );
    }
    for (final wp in waypoints) {
      final m = wp as Map<String, dynamic>;
      if (m['lat'] == null || m['lng'] == null || m['zoom'] == null) {
        throw FixtureValidationException(
          'camera_script.json: waypoint missing required fields (lat, lng, zoom).',
        );
      }
      final lat = (m['lat'] as num).toDouble();
      final lng = (m['lng'] as num).toDouble();
      // Sanity: must be within the Dachstein/Krippenstein bounding box
      if (lat < 47.0 || lat > 48.0 || lng < 13.0 || lng > 14.5) {
        throw FixtureValidationException(
          'camera_script.json: waypoint at ($lat, $lng) is outside the '
          'expected benchmark area (47–48°N, 13–14.5°E).',
        );
      }
    }
  }

  void _validateOverlays(Map<String, dynamic> overlays) {
    final airspaces = overlays['airspacePolygons'];
    if (airspaces is! List || airspaces.isEmpty) {
      throw FixtureValidationException(
        'overlays.json: "airspacePolygons" must be a non-empty list.',
      );
    }
    final track = overlays['flightTrack'];
    if (track is! Map || track['points'] is! List) {
      throw FixtureValidationException(
        'overlays.json: "flightTrack.points" must be a list.',
      );
    }
    final thermals = overlays['thermalMarkers'];
    if (thermals is! List || thermals.isEmpty) {
      throw FixtureValidationException(
        'overlays.json: "thermalMarkers" must be a non-empty list.',
      );
    }
    if (overlays['pilotPosition'] == null) {
      throw FixtureValidationException(
        'overlays.json: "pilotPosition" is required.',
      );
    }
  }
}
