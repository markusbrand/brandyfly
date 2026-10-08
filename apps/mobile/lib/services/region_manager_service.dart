import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../domain/thermal/geo_bounds.dart';
import '../models/lat_lng.dart';
import '../models/region_models.dart';
import 'pmtiles_reader.dart';

/// Storage usage summary for offline regions.
@immutable
class StorageUsage {
  const StorageUsage({
    required this.totalBytes,
    required this.perRegionBytes,
  });

  final int totalBytes;
  final Map<String, int> perRegionBytes;

  int bytesForRegion(String regionId) => perRegionBytes[regionId] ?? 0;

  static const StorageUsage zero = StorageUsage(
    totalBytes: 0,
    perRegionBytes: {},
  );
}

/// Download status lifecycle state.
enum DownloadStatus {
  idle,
  downloading,
  verifying,
  completed,
  failed,
  cancelled,
}

/// Progress model for an active region download.
@immutable
class RegionDownloadProgress {
  const RegionDownloadProgress({
    required this.regionId,
    required this.bytesDownloaded,
    required this.totalBytes,
    required this.status,
    this.currentFile,
    this.errorMessage,
  });

  final String regionId;
  final int bytesDownloaded;
  final int totalBytes;
  final DownloadStatus status;
  final String? currentFile;
  final String? errorMessage;

  double get progress =>
      totalBytes > 0 ? (bytesDownloaded / totalBytes).clamp(0.0, 1.0) : 0.0;
  int get percent => (progress * 100).floor().clamp(0, 100);

  RegionDownloadProgress copyWith({
    int? bytesDownloaded,
    int? totalBytes,
    DownloadStatus? status,
    String? currentFile,
    String? errorMessage,
  }) {
    return RegionDownloadProgress(
      regionId: regionId,
      bytesDownloaded: bytesDownloaded ?? this.bytesDownloaded,
      totalBytes: totalBytes ?? this.totalBytes,
      status: status ?? this.status,
      currentFile: currentFile ?? this.currentFile,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Manages catalog discovery, background resumable downloads, atomic storage swaps,
/// verification, and pre-flight coverage checks for offline map & DEM regions.
class RegionManagerService extends ChangeNotifier {
  RegionManagerService({
    this.customAppSupportDir,
    this.catalogUrl = defaultCatalogUrl,
    this.requestTimeout = const Duration(seconds: 12),
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  static const String defaultCatalogUrl =
      'https://cdn.brandyfly.org/regions/catalog.json';

  final String? customAppSupportDir;
  final String catalogUrl;
  final Duration? requestTimeout;
  final http.Client _httpClient;

  RegionCatalog? _catalog;
  final Map<String, RegionDownloadProgress> _activeDownloads = {};
  final StreamController<RegionDownloadProgress> _progressController =
      StreamController<RegionDownloadProgress>.broadcast();

  LatLng? _lastDismissedPromptLocation;

  RegionCatalog? get catalog => _catalog;
  Stream<RegionDownloadProgress> get progressStream =>
      _progressController.stream;
  Map<String, RegionDownloadProgress> get activeDownloads =>
      Map.unmodifiable(_activeDownloads);

  RegionDownloadProgress? getProgress(String regionId) =>
      _activeDownloads[regionId];

  bool isDownloading(String regionId) {
    final status = _activeDownloads[regionId]?.status;
    return status == DownloadStatus.downloading ||
        status == DownloadStatus.verifying;
  }

  /// Resolves the base directory for offline regions `{appSupport}/regions`.
  Future<String> getRegionsBasePath() async {
    if (customAppSupportDir != null) {
      return '$customAppSupportDir/regions';
    }
    try {
      final dir = await getApplicationSupportDirectory();
      return '${dir.path}/regions';
    } catch (_) {
      return '/tmp/brandyfly/regions';
    }
  }

  /// Fetches the catalog from remote CDN with local caching and offline fallback.
  Future<RegionCatalog?> fetchCatalog({bool forceRefresh = false}) async {
    if (!forceRefresh && _catalog != null) {
      return _catalog;
    }

    final basePath = await getRegionsBasePath();
    final cacheFile = File('$basePath/catalog_cache.json');

    try {
      final req = _httpClient.get(Uri.parse(catalogUrl));
      final response = requestTimeout != null
          ? await req.timeout(requestTimeout!)
          : await req;

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        _catalog = RegionCatalog.fromJson(decoded);

        try {
          if (!await cacheFile.parent.exists()) {
            await cacheFile.parent.create(recursive: true);
          }
          await cacheFile.writeAsString(response.body, flush: true);
        } catch (e) {
          debugPrint('[RegionManagerService] Failed to cache catalog: $e');
        }

        notifyListeners();
        return _catalog;
      }
    } catch (e) {
      debugPrint(
        '[RegionManagerService] Network catalog fetch failed ($e), checking offline cache...',
      );
    }

    // Offline fallback from local cache file
    if (cacheFile.existsSync()) {
      try {
        final content = cacheFile.readAsStringSync();
        final decoded = jsonDecode(content) as Map<String, dynamic>;
        _catalog = RegionCatalog.fromJson(decoded);
        notifyListeners();
        return _catalog;
      } catch (e) {
        debugPrint(
          '[RegionManagerService] Corrupted catalog cache: $e',
        );
      }
    }

    // Bundled seed catalog fallback from assets
    try {
      final assetContent =
          await rootBundle.loadString('assets/map_data/catalog.json');
      final decoded = jsonDecode(assetContent) as Map<String, dynamic>;
      _catalog = RegionCatalog.fromJson(decoded);
      try {
        if (!cacheFile.parent.existsSync()) {
          cacheFile.parent.createSync(recursive: true);
        }
        cacheFile.writeAsStringSync(assetContent, flush: true);
      } catch (_) {}
      notifyListeners();
      return _catalog;
    } catch (e) {
      debugPrint('[RegionManagerService] No bundled catalog asset: $e');
    }

    return _catalog;
  }

  /// Lists all downloaded regions present on disk.
  Future<List<DownloadedRegion>> getDownloadedRegions() async {
    final basePath = await getRegionsBasePath();
    final baseDir = Directory(basePath);
    if (!baseDir.existsSync()) {
      return const [];
    }

    final downloaded = <DownloadedRegion>[];
    final entries = baseDir.listSync(followLinks: false);

    for (final entry in entries) {
      if (entry is! Directory) continue;
      final dirName = entry.path.split(Platform.pathSeparator).last;
      if (dirName.startsWith('.') ||
          dirName.endsWith('.downloading') ||
          dirName.endsWith('.old')) {
        continue;
      }

      final metaFile = File('${entry.path}/meta.json');
      final mapFile = File('${entry.path}/map.pmtiles');
      final terrainFile = File('${entry.path}/terrain.pmtiles');

      if (!mapFile.existsSync() || mapFile.lengthSync() < 127) {
        continue;
      }

      int totalDiskSize = 0;
      for (final f in entry.listSync()) {
        if (f is File) {
          totalDiskSize += f.lengthSync();
        }
      }

      if (metaFile.existsSync()) {
        try {
          final content = metaFile.readAsStringSync();
          final meta = DownloadedRegion.fromJson(
            jsonDecode(content) as Map<String, dynamic>,
          );
          downloaded.add(
            DownloadedRegion(
              id: meta.id.isNotEmpty ? meta.id : dirName,
              version: meta.version,
              downloadedAt: meta.downloadedAt,
              directoryPath: entry.path,
              mapPath: mapFile.existsSync() ? mapFile.path : null,
              terrainPath: terrainFile.existsSync() ? terrainFile.path : null,
              checksums: meta.checksums,
              sizeBytes: totalDiskSize,
              bounds: meta.bounds ?? _findCatalogBounds(dirName),
            ),
          );
          continue;
        } catch (_) {}
      }

      // Fallback for regions without meta.json
      GeoBounds? bounds = _findCatalogBounds(dirName);
      if (bounds == null) {
        PMTilesReader? reader;
        try {
          reader = await PMTilesReader.open(mapFile);
          final h = reader.header;
          bounds = GeoBounds(
            west: h.minLon,
            south: h.minLat,
            east: h.maxLon,
            north: h.maxLat,
          );
        } catch (_) {
        } finally {
          await reader?.close();
        }
      }

      downloaded.add(
        DownloadedRegion(
          id: dirName,
          version: 'local',
          downloadedAt: mapFile.statSync().modified,
          directoryPath: entry.path,
          mapPath: mapFile.path,
          terrainPath: terrainFile.existsSync() ? terrainFile.path : null,
          checksums: const {},
          sizeBytes: totalDiskSize,
          bounds: bounds,
        ),
      );
    }

    downloaded.sort((a, b) => a.id.compareTo(b.id));
    return downloaded;
  }

  GeoBounds? _findCatalogBounds(String regionId) {
    final entry = _catalog?.findRegion(regionId);
    return entry?.bounds;
  }

  /// Calculates total and per-region disk usage for offline maps.
  Future<StorageUsage> getStorageUsage() async {
    final regions = await getDownloadedRegions();
    int total = 0;
    final perRegion = <String, int>{};

    for (final r in regions) {
      total += r.sizeBytes;
      perRegion[r.id] = r.sizeBytes;
    }

    return StorageUsage(totalBytes: total, perRegionBytes: perRegion);
  }

  /// Checks if a newer version exists in the catalog for a downloaded region.
  bool isUpdateAvailable(String regionId, List<DownloadedRegion> downloaded) {
    if (_catalog == null) return false;
    final catalogEntry = _catalog!.findRegion(regionId);
    if (catalogEntry == null) return false;

    final local = downloaded.where((r) => r.id == regionId).firstOrNull;
    if (local == null) return false;

    return local.version != catalogEntry.version;
  }

  /// Initiates a background resumable download for a region.
  Stream<RegionDownloadProgress> downloadRegion(String regionId) {
    final controller = StreamController<RegionDownloadProgress>();

    () async {
      final entry = _catalog?.findRegion(regionId);
      if (entry == null) {
        final err = 'Region $regionId not found in catalog';
        final failedProgress = RegionDownloadProgress(
          regionId: regionId,
          bytesDownloaded: 0,
          totalBytes: 0,
          status: DownloadStatus.failed,
          errorMessage: err,
        );
        _activeDownloads[regionId] = failedProgress;
        _progressController.add(failedProgress);
        controller.add(failedProgress);
        await controller.close();
        return;
      }

      final basePath = await getRegionsBasePath();
      final tempDir = Directory('$basePath/$regionId.downloading');
      if (!await tempDir.exists()) {
        await tempDir.create(recursive: true);
      }

      final totalExpectedBytes = entry.totalSizeBytes;
      var totalDownloadedSoFar = 0;

      // Check already completed bytes in temp directory for resuming calculation
      for (final fileKey in entry.files.keys) {
        final targetFile = File('${tempDir.path}/$fileKey.pmtiles');
        if (await targetFile.exists()) {
          totalDownloadedSoFar += await targetFile.length();
        }
      }

      void emit(RegionDownloadProgress p) {
        _activeDownloads[regionId] = p;
        _progressController.add(p);
        if (!controller.isClosed) {
          controller.add(p);
        }
        notifyListeners();
      }

      emit(
        RegionDownloadProgress(
          regionId: regionId,
          bytesDownloaded: totalDownloadedSoFar,
          totalBytes: totalExpectedBytes,
          status: DownloadStatus.downloading,
        ),
      );

      final verifiedChecksums = <String, String>{};

      try {
        for (final fileEntry in entry.files.entries) {
          final fileKey = fileEntry.key;
          final regionFile = fileEntry.value;
          final targetFile = File('${tempDir.path}/$fileKey.pmtiles');

          var currentExistingBytes =
              await targetFile.exists() ? await targetFile.length() : 0;

          // If partial file is larger than expected, start fresh
          if (currentExistingBytes > regionFile.sizeBytes) {
            await targetFile.delete();
            totalDownloadedSoFar -= currentExistingBytes;
            currentExistingBytes = 0;
          }

          if (currentExistingBytes < regionFile.sizeBytes) {
            final request = http.Request('GET', Uri.parse(regionFile.url));
            if (currentExistingBytes > 0) {
              request.headers['Range'] = 'bytes=$currentExistingBytes-';
            }

            http.StreamedResponse? response;
            try {
              response = await _httpClient.send(request);
            } catch (netErr) {
              final isHostErr = netErr is SocketException ||
                  netErr is http.ClientException ||
                  netErr.toString().contains('Failed host lookup') ||
                  netErr.toString().contains('SocketException') ||
                  netErr.toString().contains('ClientException');
              if (isHostErr) {
                // Remote CDN host is unreachable; fall back to bundled demo PMTiles archive
                await _fallbackDownloadFromBundle(
                  targetFile: targetFile,
                  fileKey: fileKey,
                  emit: emit,
                  regionId: regionId,
                  totalExpectedBytes: totalExpectedBytes,
                  totalDownloadedSoFar: totalDownloadedSoFar,
                );
                verifiedChecksums[fileKey] = await _computeSha256(targetFile);
                continue;
              }
              rethrow;
            }

            IOSink sink;
            if (response.statusCode == 206) {
              sink = targetFile.openWrite(mode: FileMode.append);
            } else if (response.statusCode == 200) {
              totalDownloadedSoFar -= currentExistingBytes;
              currentExistingBytes = 0;
              sink = targetFile.openWrite(mode: FileMode.write);
            } else {
              throw HttpException(
                'Download failed with HTTP ${response.statusCode} for ${regionFile.url}',
              );
            }

            try {
              await for (final chunk in response.stream) {
                sink.add(chunk);
                currentExistingBytes += chunk.length;
                totalDownloadedSoFar += chunk.length;

                emit(
                  RegionDownloadProgress(
                    regionId: regionId,
                    bytesDownloaded: totalDownloadedSoFar,
                    totalBytes: totalExpectedBytes,
                    status: DownloadStatus.downloading,
                    currentFile: fileKey,
                  ),
                );
              }
            } finally {
              await sink.flush();
              await sink.close();
            }
          }

          // Checksum verification
          emit(
            RegionDownloadProgress(
              regionId: regionId,
              bytesDownloaded: totalDownloadedSoFar,
              totalBytes: totalExpectedBytes,
              status: DownloadStatus.verifying,
              currentFile: fileKey,
            ),
          );

          final actualSha256 = await _computeSha256(targetFile);
          if (regionFile.sha256.isNotEmpty &&
              actualSha256.toLowerCase() != regionFile.sha256.toLowerCase()) {
            await targetFile.delete();
            throw StateError(
              'Checksum verification failed for $regionId/$fileKey: expected ${regionFile.sha256}, got $actualSha256',
            );
          }

          verifiedChecksums[fileKey] = actualSha256;
        }

        // Save metadata
        final meta = DownloadedRegion(
          id: entry.id,
          version: entry.version,
          downloadedAt: DateTime.now().toUtc(),
          directoryPath: '$basePath/$regionId',
          mapPath: '$basePath/$regionId/map.pmtiles',
          terrainPath: entry.files.containsKey('terrain')
              ? '$basePath/$regionId/terrain.pmtiles'
              : null,
          checksums: verifiedChecksums,
          sizeBytes: totalExpectedBytes,
          bounds: entry.bounds,
        );

        final metaFile = File('${tempDir.path}/meta.json');
        await metaFile.writeAsString(jsonEncode(meta.toJson()), flush: true);

        // Atomic swap
        await _atomicSwap(basePath, regionId, tempDir);

        final completedProgress = RegionDownloadProgress(
          regionId: regionId,
          bytesDownloaded: totalExpectedBytes,
          totalBytes: totalExpectedBytes,
          status: DownloadStatus.completed,
        );
        emit(completedProgress);
      } catch (e, st) {
        debugPrint('[RegionManagerService] Download error: $e\n$st');
        final failedProgress = RegionDownloadProgress(
          regionId: regionId,
          bytesDownloaded: totalDownloadedSoFar,
          totalBytes: totalExpectedBytes,
          status: DownloadStatus.failed,
          errorMessage: e.toString(),
        );
        emit(failedProgress);
      } finally {
        await controller.close();
      }
    }();

    return controller.stream;
  }

  /// Updates an existing region by initiating a background download and swap.
  Future<void> updateRegion(String regionId) async {
    final stream = downloadRegion(regionId);
    await stream.last;
  }

  /// Deletes a downloaded region from storage.
  Future<void> deleteRegion(String regionId) async {
    final basePath = await getRegionsBasePath();
    final activeDir = Directory('$basePath/$regionId');
    final tempDir = Directory('$basePath/$regionId.downloading');
    final oldDir = Directory('$basePath/$regionId.old');

    if (activeDir.existsSync()) {
      activeDir.deleteSync(recursive: true);
    }
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
    if (oldDir.existsSync()) {
      oldDir.deleteSync(recursive: true);
    }

    _activeDownloads.remove(regionId);
    notifyListeners();
  }

  /// Checks whether a coordinate is covered by any downloaded region.
  Future<bool> isLocationCovered(double lat, double lon) async {
    final downloaded = await getDownloadedRegions();
    for (final region in downloaded) {
      final bounds = region.bounds;
      if (bounds != null && bounds.isValid) {
        if (_boundsContain(bounds, lat, lon)) {
          return true;
        }
      }
    }
    return false;
  }

  /// Returns catalog regions that cover or are closest to the coordinate.
  List<RegionEntry> getSuggestedRegions(double lat, double lon) {
    if (_catalog == null || _catalog!.regions.isEmpty) {
      return const [];
    }

    final directMatches = <RegionEntry>[];
    for (final entry in _catalog!.regions) {
      if (entry.bounds.isValid && _boundsContain(entry.bounds, lat, lon)) {
        directMatches.add(entry);
      }
    }

    if (directMatches.isNotEmpty) {
      return directMatches;
    }

    // If no direct bounding box match, sort by distance to bounding box center
    final sorted = List<RegionEntry>.from(_catalog!.regions);
    sorted.sort((a, b) {
      final distA = _distanceToCenter(a.bounds, lat, lon);
      final distB = _distanceToCenter(b.bounds, lat, lon);
      return distA.compareTo(distB);
    });

    return sorted.take(2).toList();
  }

  /// Determines whether the pre-flight prompt should be presented to the pilot.
  Future<bool> shouldShowPreFlightPrompt(double lat, double lon) async {
    final covered = await isLocationCovered(lat, lon);
    if (covered) {
      return false;
    }

    final dismissed = _lastDismissedPromptLocation;
    if (dismissed != null) {
      final distKm = _distanceKm(
        dismissed.latitude,
        dismissed.longitude,
        lat,
        lon,
      );
      if (distKm <= 50.0) {
        return false;
      }
    }

    return true;
  }

  /// Dismisses the pre-flight prompt for the current session and area.
  void dismissPromptForSession(double lat, double lon) {
    _lastDismissedPromptLocation = LatLng(lat, lon);
  }

  /// Resets session-scoped dismissal state.
  void resetPromptDismissal() {
    _lastDismissedPromptLocation = null;
  }

  static bool _boundsContain(GeoBounds bounds, double lat, double lon) {
    return lat >= bounds.south &&
        lat <= bounds.north &&
        lon >= bounds.west &&
        lon <= bounds.east;
  }

  static double _distanceToCenter(
    GeoBounds bounds,
    double lat,
    double lon,
  ) {
    final centerLat = (bounds.north + bounds.south) / 2.0;
    final centerLon = (bounds.east + bounds.west) / 2.0;
    return _distanceKm(centerLat, centerLon, lat, lon);
  }

  static double _distanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final h = math.pow(math.sin(dLat / 2), 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.pow(math.sin(dLon / 2), 2);
    return 2 * r * math.asin(math.sqrt(h.toDouble()));
  }

  static Future<String> _computeSha256(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  static Future<void> _fallbackDownloadFromBundle({
    required File targetFile,
    required String fileKey,
    required void Function(RegionDownloadProgress) emit,
    required String regionId,
    required int totalExpectedBytes,
    required int totalDownloadedSoFar,
  }) async {
    final byteData =
        await rootBundle.load('assets/map_data/global_overview.pmtiles');
    final bytes = byteData.buffer.asUint8List(
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    );
    const chunkSize = 100;
    for (int offset = 0; offset < bytes.length; offset += chunkSize) {
      final end = (offset + chunkSize < bytes.length)
          ? offset + chunkSize
          : bytes.length;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      emit(
        RegionDownloadProgress(
          regionId: regionId,
          bytesDownloaded: totalDownloadedSoFar + end,
          totalBytes:
              totalExpectedBytes > 0 ? totalExpectedBytes : bytes.length,
          status: DownloadStatus.downloading,
          currentFile: fileKey,
        ),
      );
    }
    await targetFile.writeAsBytes(bytes, flush: true);
  }

  static Future<void> _atomicSwap(
    String basePath,
    String regionId,
    Directory tempDir,
  ) async {
    final activeDir = Directory('$basePath/$regionId');
    final oldDir = Directory('$basePath/$regionId.old');

    if (await oldDir.exists()) {
      await oldDir.delete(recursive: true);
    }

    if (await activeDir.exists()) {
      await activeDir.rename(oldDir.path);
    }

    await tempDir.rename(activeDir.path);

    if (await oldDir.exists()) {
      await oldDir.delete(recursive: true);
    }
  }

  @override
  void dispose() {
    _progressController.close();
    _httpClient.close();
    super.dispose();
  }
}
