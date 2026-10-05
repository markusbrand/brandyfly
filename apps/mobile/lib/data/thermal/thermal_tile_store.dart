import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/thermal/thermal_variant.dart';

/// Persistent, file-based storage for KK7 thermal tiles.
///
/// Layout (XYZ addressing, see design D2):
/// ```
/// {appSupport}/regions/<id>/thermals/<season>_<time>/<z>/<x>/<y>.png
/// {appSupport}/thermal_cache/<season>_<time>/<z>/<x>/<y>.png
/// ```
/// A zero-byte file is a marker for "the provider has no data for this
/// tile"; readers receive an empty [Uint8List] for it. Writes are atomic
/// (temp file + rename). Everything lives in application support storage,
/// which the operating system does not purge like the temp directory.
class ThermalTileStore {
  ThermalTileStore({
    this.appSupportDir,
    this.maxCacheBytes = defaultMaxCacheBytes,
    this.regionListTtl = const Duration(seconds: 5),
  });

  static const int defaultMaxCacheBytes = 200 * 1024 * 1024;

  /// Name of the per-region thermal tile directory.
  static const String regionThermalDirName = 'thermals';

  /// Fixed application support directory (null = platform default).
  final String? appSupportDir;
  final int maxCacheBytes;
  final Duration regionListTtl;

  String? _resolvedAppSupport;
  List<String>? _regionThermalDirs;
  DateTime? _regionThermalDirsAt;
  int? _approxCacheBytes;
  Future<void>? _evicting;

  Future<String> appSupportPath() async {
    final configured = appSupportDir;
    if (configured != null) return configured;
    final resolved = _resolvedAppSupport;
    if (resolved != null) return resolved;
    String path;
    try {
      path = (await getApplicationSupportDirectory()).path;
    } catch (_) {
      path = '${Directory.systemTemp.path}/brandyfly_support';
    }
    _resolvedAppSupport = path;
    return path;
  }

  Future<String> regionsBasePath() async => '${await appSupportPath()}/regions';

  Future<String> cacheBasePath() async =>
      '${await appSupportPath()}/thermal_cache';

  /// Root of thermal tiles stored for the region at [regionDirectory].
  static String regionThermalRoot(String regionDirectory) =>
      '$regionDirectory/$regionThermalDirName';

  static String tileRelativePath(ThermalVariant v, int z, int x, int y) =>
      '${v.key}/$z/$x/$y.png';

  /// Forces the next region lookup to rescan the regions directory.
  void invalidateRegionList() {
    _regionThermalDirs = null;
    _regionThermalDirsAt = null;
  }

  Future<List<String>> _regionThermalRoots() async {
    final now = DateTime.now();
    final cached = _regionThermalDirs;
    final at = _regionThermalDirsAt;
    if (cached != null && at != null && now.difference(at) < regionListTtl) {
      return cached;
    }
    final roots = <String>[];
    try {
      final base = Directory(await regionsBasePath());
      if (await base.exists()) {
        await for (final e in base.list(followLinks: false)) {
          if (e is! Directory) continue;
          final root = regionThermalRoot(e.path);
          if (await Directory(root).exists()) roots.add(root);
        }
      }
    } catch (e) {
      debugPrint('[ThermalTileStore] region scan failed: $e');
    }
    _regionThermalDirs = roots;
    _regionThermalDirsAt = now;
    return roots;
  }

  /// Looks up a tile prefetched for any downloaded region. Returns null on
  /// a miss and an empty list for a known-empty tile.
  Future<Uint8List?> readFromRegions(
    ThermalVariant v,
    int z,
    int x,
    int y,
  ) async {
    final rel = tileRelativePath(v, z, x, y);
    for (final root in await _regionThermalRoots()) {
      final bytes = await _readIfExists(File('$root/$rel'));
      if (bytes != null) return bytes;
    }
    return null;
  }

  /// Looks up a tile in the persistent browse cache (null on a miss, empty
  /// for a known-empty tile). Hits refresh the file's LRU timestamp.
  Future<Uint8List?> readFromCache(
    ThermalVariant v,
    int z,
    int x,
    int y,
  ) async {
    final file = File(
      '${await cacheBasePath()}/${tileRelativePath(v, z, x, y)}',
    );
    final bytes = await _readIfExists(file);
    if (bytes != null) {
      unawaited(file.setLastModified(DateTime.now()).catchError((Object _) {}));
    }
    return bytes;
  }

  /// Stores a tile in the browse cache; empty [bytes] store a marker.
  Future<void> writeToCache(
    ThermalVariant v,
    int z,
    int x,
    int y,
    Uint8List bytes,
  ) async {
    final base = await cacheBasePath();
    // Measure once before the first write; later writes are added up and
    // the eviction scan re-synchronises the estimate with the disk.
    _approxCacheBytes ??= await _directorySize(Directory(base));
    try {
      await writeAtomic(File('$base/${tileRelativePath(v, z, x, y)}'), bytes);
    } catch (e) {
      debugPrint('[ThermalTileStore] cache write failed for $z/$x/$y: $e');
      return;
    }
    _approxCacheBytes = _approxCacheBytes! + bytes.length;
    if (_approxCacheBytes! > maxCacheBytes) {
      await (_evicting ??= _evict(base).whenComplete(() => _evicting = null));
    }
  }

  /// Current size of the browse cache on disk in bytes.
  Future<int> cacheSizeBytes() async =>
      _directorySize(Directory(await cacheBasePath()));

  /// Deletes least-recently-used cache files until the cache is at most
  /// 80 % of [maxCacheBytes].
  Future<void> _evict(String base) async {
    final files = <(File, DateTime, int)>[];
    var total = 0;
    try {
      await for (final e in Directory(base).list(recursive: true)) {
        if (e is! File || e.path.endsWith('.tmp')) continue;
        final stat = await e.stat();
        files.add((e, stat.modified, stat.size));
        total += stat.size;
      }
    } catch (_) {}
    files.sort((a, b) => a.$2.compareTo(b.$2));
    final target = (maxCacheBytes * 0.8).floor();
    for (final (file, _, size) in files) {
      if (total <= target) break;
      try {
        await file.delete();
        total -= size;
      } catch (_) {}
    }
    _approxCacheBytes = total;
  }

  /// Writes [bytes] to [file] atomically via a temporary sibling file.
  static Future<void> writeAtomic(File file, List<int> bytes) async {
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(file.path);
  }

  static Future<Uint8List?> _readIfExists(File file) async {
    try {
      if (!await file.exists()) return null;
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  static Future<int> _directorySize(Directory dir) async {
    var total = 0;
    try {
      if (!await dir.exists()) return 0;
      await for (final e in dir.list(recursive: true)) {
        if (e is File) total += await e.length();
      }
    } catch (_) {}
    return total;
  }
}
