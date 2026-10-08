import 'package:flutter/foundation.dart';
import '../domain/thermal/geo_bounds.dart';

/// Single downloadable region file (e.g. vector map or terrain DEM).
@immutable
class RegionFile {
  const RegionFile({
    required this.url,
    required this.sizeBytes,
    required this.sha256,
  });

  final String url;
  final int sizeBytes;
  final String sha256;

  Map<String, dynamic> toJson() => {
        'url': url,
        'sizeBytes': sizeBytes,
        'sha256': sha256,
      };

  factory RegionFile.fromJson(Map<String, dynamic> json) => RegionFile(
        url: json['url'] as String? ?? '',
        sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
        sha256: json['sha256'] as String? ?? '',
      );
}

/// A flight area region available in the remote catalog.
@immutable
class RegionEntry {
  const RegionEntry({
    required this.id,
    required this.name,
    required this.description,
    required this.bounds,
    required this.version,
    required this.generatedAt,
    required this.files,
  });

  final String id;
  final String name;
  final String description;
  final GeoBounds bounds;
  final String version;
  final DateTime generatedAt;
  final Map<String, RegionFile> files;

  RegionFile? get mapFile => files['map'];
  RegionFile? get terrainFile => files['terrain'];

  int get totalSizeBytes =>
      files.values.fold(0, (sum, f) => sum + f.sizeBytes);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'bounds': {
          'north': bounds.north,
          'south': bounds.south,
          'west': bounds.west,
          'east': bounds.east,
        },
        'version': version,
        'generatedAt': generatedAt.toIso8601String(),
        'files': files.map((k, v) => MapEntry(k, v.toJson())),
      };

  factory RegionEntry.fromJson(Map<String, dynamic> json) {
    final boundsJson = json['bounds'] as Map<String, dynamic>? ?? {};
    final bounds = GeoBounds(
      west: (boundsJson['west'] as num?)?.toDouble() ?? 0.0,
      south: (boundsJson['south'] as num?)?.toDouble() ?? 0.0,
      east: (boundsJson['east'] as num?)?.toDouble() ?? 0.0,
      north: (boundsJson['north'] as num?)?.toDouble() ?? 0.0,
    );
    final filesJson = json['files'] as Map<String, dynamic>? ?? {};
    final files = filesJson.map(
      (k, v) => MapEntry(
        k,
        RegionFile.fromJson(v as Map<String, dynamic>),
      ),
    );

    return RegionEntry(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      bounds: bounds,
      version: json['version'] as String? ?? '',
      generatedAt: DateTime.tryParse(json['generatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      files: files,
    );
  }
}

/// Catalog listing all available regional datasets hosted on CDN.
@immutable
class RegionCatalog {
  const RegionCatalog({
    required this.catalogVersion,
    required this.generatedAt,
    required this.regions,
  });

  final int catalogVersion;
  final DateTime generatedAt;
  final List<RegionEntry> regions;

  RegionEntry? findRegion(String id) {
    try {
      return regions.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
        'catalogVersion': catalogVersion,
        'generatedAt': generatedAt.toIso8601String(),
        'regions': regions.map((r) => r.toJson()).toList(),
      };

  factory RegionCatalog.fromJson(Map<String, dynamic> json) {
    final list = json['regions'] as List<dynamic>? ?? [];
    return RegionCatalog(
      catalogVersion: (json['catalogVersion'] as num?)?.toInt() ?? 1,
      generatedAt: DateTime.tryParse(json['generatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      regions: list
          .map((e) => RegionEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Region that has been downloaded and verified locally.
@immutable
class DownloadedRegion {
  const DownloadedRegion({
    required this.id,
    required this.version,
    required this.downloadedAt,
    required this.directoryPath,
    this.mapPath,
    this.terrainPath,
    this.checksums = const {},
    this.sizeBytes = 0,
    this.bounds,
  });

  final String id;
  final String version;
  final DateTime downloadedAt;
  final String directoryPath;
  final String? mapPath;
  final String? terrainPath;
  final Map<String, String> checksums;
  final int sizeBytes;
  final GeoBounds? bounds;

  Map<String, dynamic> toJson() => {
        'id': id,
        'version': version,
        'downloadedAt': downloadedAt.toIso8601String(),
        'directoryPath': directoryPath,
        'mapPath': mapPath,
        'terrainPath': terrainPath,
        'checksums': checksums,
        'sizeBytes': sizeBytes,
        if (bounds != null)
          'bounds': {
            'north': bounds!.north,
            'south': bounds!.south,
            'west': bounds!.west,
            'east': bounds!.east,
          },
      };

  factory DownloadedRegion.fromJson(Map<String, dynamic> json) {
    GeoBounds? bounds;
    if (json['bounds'] != null) {
      final b = json['bounds'] as Map<String, dynamic>;
      bounds = GeoBounds(
        west: (b['west'] as num?)?.toDouble() ?? 0.0,
        south: (b['south'] as num?)?.toDouble() ?? 0.0,
        east: (b['east'] as num?)?.toDouble() ?? 0.0,
        north: (b['north'] as num?)?.toDouble() ?? 0.0,
      );
    }
    return DownloadedRegion(
      id: json['id'] as String? ?? '',
      version: json['version'] as String? ?? '',
      downloadedAt: DateTime.tryParse(json['downloadedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      directoryPath: json['directoryPath'] as String? ?? '',
      mapPath: json['mapPath'] as String?,
      terrainPath: json['terrainPath'] as String?,
      checksums: (json['checksums'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v.toString())) ??
          const {},
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      bounds: bounds,
    );
  }
}
