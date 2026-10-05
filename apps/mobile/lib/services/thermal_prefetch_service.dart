import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../data/thermal/region_bounds_provider.dart';
import '../data/thermal/thermal_tile_store.dart';
import '../domain/thermal/kk7_provider.dart';
import '../domain/thermal/thermal_prefetch_planner.dart';
import '../domain/thermal/thermal_variant.dart';
import 'local_tile_server.dart';

/// Fetches one KK7 tile: PNG bytes, empty list for "no data", null for a
/// non-retryable failure. Throws [Kk7HttpException] for 429/5xx and
/// network exceptions ([SocketException], [TimeoutException], ...) when
/// the device is offline.
typedef Kk7TileFetcher = Future<Uint8List?> Function(Uri uri);

typedef PrefetchSleep = Future<void> Function(Duration duration);

/// Lifecycle state of a region's thermal prefetch.
enum ThermalPrefetchStatus {
  notPrefetched,
  inProgress,
  complete,
  partial,
  failed,
}

/// Observable thermal prefetch state of one downloaded region.
@immutable
class RegionThermalState {
  const RegionThermalState({
    required this.regionId,
    this.status = ThermalPrefetchStatus.notPrefetched,
    this.totalTiles = 0,
    this.storedTiles = 0,
    this.bytes = 0,
    this.completeVariants = const {},
    this.updatedAt,
    this.lastError,
  });

  final String regionId;
  final ThermalPrefetchStatus status;
  final int totalTiles;
  final int storedTiles;
  final int bytes;

  /// Variant keys (e.g. `jul_07`) completely stored for the region.
  final Set<String> completeVariants;
  final DateTime? updatedAt;
  final String? lastError;

  double get progress => totalTiles == 0 ? 0 : storedTiles / totalTiles;

  int get percent => (progress * 100).floor().clamp(0, 100);

  /// Season bins whose four time-of-day variants are all stored.
  List<ThermalSeason> get completeSeasons => [
    for (final s in ThermalSeason.values)
      if (s != ThermalSeason.auto &&
          ThermalVariant.allTimesOf(
            s,
          ).every((v) => completeVariants.contains(v.key)))
        s,
  ];

  RegionThermalState copyWith({
    ThermalPrefetchStatus? status,
    int? totalTiles,
    int? storedTiles,
    int? bytes,
    Set<String>? completeVariants,
    DateTime? updatedAt,
    String? lastError,
    bool clearError = false,
  }) => RegionThermalState(
    regionId: regionId,
    status: status ?? this.status,
    totalTiles: totalTiles ?? this.totalTiles,
    storedTiles: storedTiles ?? this.storedTiles,
    bytes: bytes ?? this.bytes,
    completeVariants: completeVariants ?? this.completeVariants,
    updatedAt: updatedAt ?? this.updatedAt,
    lastError: clearError ? null : (lastError ?? this.lastError),
  );

  Map<String, dynamic> toJson() => {
    'status': status.name,
    'totalTiles': totalTiles,
    'storedTiles': storedTiles,
    'bytes': bytes,
    'completeVariants': completeVariants.toList()..sort(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    if (lastError != null) 'lastError': lastError,
  };

  factory RegionThermalState.fromJson(String regionId, Map<String, dynamic> j) {
    var status = ThermalPrefetchStatus.notPrefetched;
    try {
      status = ThermalPrefetchStatus.values.byName(j['status'] as String);
    } catch (_) {}
    // A run interrupted by an app kill resumes as partial.
    if (status == ThermalPrefetchStatus.inProgress) {
      status = ThermalPrefetchStatus.partial;
    }
    return RegionThermalState(
      regionId: regionId,
      status: status,
      totalTiles: (j['totalTiles'] as num?)?.toInt() ?? 0,
      storedTiles: (j['storedTiles'] as num?)?.toInt() ?? 0,
      bytes: (j['bytes'] as num?)?.toInt() ?? 0,
      completeVariants: {
        for (final v in (j['completeVariants'] as List?) ?? const []) '$v',
      },
      updatedAt: DateTime.tryParse('${j['updatedAt']}'),
      lastError: j['lastError'] as String?,
    );
  }
}

/// Serialising token-spacing rate limiter: request starts are spaced at
/// least `1 / maxPerSecond` apart, so no 1-second window holds more than
/// [maxPerSecond] starts.
class PrefetchRateLimiter {
  PrefetchRateLimiter({
    required this.maxPerSecond,
    required this.now,
    required this.sleep,
  });

  final double maxPerSecond;
  final DateTime Function() now;
  final PrefetchSleep sleep;
  DateTime? _nextSlot;
  Future<void> _chain = Future.value();

  Duration get interval => Duration(
    microseconds: (Duration.microsecondsPerSecond / maxPerSecond).ceil(),
  );

  Future<void> acquire() {
    final next = _chain.then((_) => _acquire());
    _chain = next;
    return next;
  }

  Future<void> _acquire() async {
    final t = now();
    final slot = _nextSlot == null || _nextSlot!.isBefore(t) ? t : _nextSlot!;
    _nextSlot = slot.add(interval);
    final wait = slot.difference(t);
    if (wait > Duration.zero) await sleep(wait);
  }
}

/// Exponential backoff: 1 s, 2 s, 4 s ... capped at 5 minutes.
Duration prefetchBackoff(int attempt) {
  final seconds = math.min(300, 1 << (attempt - 1).clamp(0, 16));
  return Duration(seconds: seconds);
}

/// Downloads KK7 thermal tiles for every downloaded map region onto the
/// device (see design D5). Network I/O is asynchronous and rate limited so
/// flight instruments and map rendering are unaffected.
class ThermalPrefetchService extends ChangeNotifier {
  ThermalPrefetchService({
    required this.store,
    required this.regions,
    Kk7TileFetcher? fetcher,
    DateTime Function()? clock,
    PrefetchSleep? sleep,
    bool Function()? autoPrefetchEnabled,
    this.kk7BaseUrl = Kk7Provider.defaultBaseUrl,
    this.maxConcurrent = 2,
    this.maxRequestsPerSecond = 4,
    this.maxAttempts = 6,
    this.offlineRetryDelay = const Duration(minutes: 15),
    this.recheckInterval = const Duration(hours: 1),
  }) : _clock = clock ?? DateTime.now,
       _sleep = sleep ?? Future<void>.delayed,
       _autoEnabled = autoPrefetchEnabled ?? (() => true) {
    _fetcher = fetcher;
    _limiter = PrefetchRateLimiter(
      maxPerSecond: maxRequestsPerSecond.toDouble(),
      now: _clock,
      sleep: _sleep,
    );
  }

  static const String stateFileName = 'state.json';

  final ThermalTileStore store;
  final RegionBoundsProvider regions;
  final String kk7BaseUrl;
  final int maxConcurrent;
  final int maxRequestsPerSecond;
  final int maxAttempts;
  final Duration offlineRetryDelay;
  final Duration recheckInterval;

  final DateTime Function() _clock;
  final PrefetchSleep _sleep;
  final bool Function() _autoEnabled;
  Kk7TileFetcher? _fetcher;
  HttpClient? _ownedClient;
  late final PrefetchRateLimiter _limiter;

  final Map<String, RegionThermalState> _states = {};
  final List<String> _queue = [];
  Future<void>? _draining;
  Timer? _recheckTimer;
  Timer? _offlineRetryTimer;
  bool _disposed = false;

  /// Current state per downloaded region id.
  Map<String, RegionThermalState> get states => Map.unmodifiable(_states);

  bool get autoPrefetchEnabled => _autoEnabled();

  /// Completes when all queued prefetch work has finished.
  Future<void> get idle => _draining ?? Future.value();

  Kk7TileFetcher get _fetch => _fetcher ??= _defaultFetcher();

  Kk7TileFetcher _defaultFetcher() {
    final client = _ownedClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    return (uri) => LocalTileServer.fetchKk7Tile(
      client,
      uri,
    ).timeout(const Duration(seconds: 20));
  }

  /// Loads persisted state, runs automatic prefetch and starts the periodic
  /// re-check (date / season-window changes, newly added regions).
  Future<void> start() async {
    await refreshStates();
    _recheckTimer ??= Timer.periodic(recheckInterval, (_) => runAutomatic());
    await runAutomatic();
  }

  /// Hook for app resume and for the region manager after a download or
  /// deletion.
  Future<void> notifyRegionsChanged() async {
    store.invalidateRegionList();
    await refreshStates();
    await runAutomatic();
  }

  /// Re-reads regions and their persisted prefetch state from disk.
  Future<void> refreshStates() async {
    final list = await regions.listRegions();
    final ids = {for (final r in list) r.id};
    _states.removeWhere((id, s) => !ids.contains(id));
    for (final r in list) {
      if (_states[r.id]?.status == ThermalPrefetchStatus.inProgress) continue;
      _states[r.id] = await _readState(r);
    }
    _notify();
  }

  /// Starts prefetch for every region whose required variants are not
  /// completely stored. No-op when automatic prefetch is disabled.
  Future<void> runAutomatic() async {
    if (!_autoEnabled() || _disposed) return;
    final required = ThermalPrefetchPlanner.requiredVariants(_clock());
    for (final r in await regions.listRegions()) {
      final state = _states[r.id] ?? await _readState(r);
      _states[r.id] = state;
      final complete = required.every(
        (v) => state.completeVariants.contains(v.key),
      );
      if (!complete) _enqueue(r.id);
    }
    _notify();
    await idle;
  }

  /// Manually starts or retries prefetch for [regionId] (ignores the
  /// automatic prefetch setting).
  Future<void> prefetchRegion(String regionId) async {
    _enqueue(regionId);
    await idle;
  }

  void _enqueue(String regionId) {
    if (_queue.contains(regionId) ||
        _states[regionId]?.status == ThermalPrefetchStatus.inProgress) {
      return;
    }
    _queue.add(regionId);
    _draining ??= _drain().whenComplete(() => _draining = null);
  }

  Future<void> _drain() async {
    while (_queue.isNotEmpty && !_disposed) {
      final id = _queue.removeAt(0);
      final region = (await regions.listRegions())
          .where((r) => r.id == id)
          .firstOrNull;
      if (region == null) {
        _states.remove(id);
        continue;
      }
      await _runRegion(region);
    }
  }

  Future<void> _runRegion(LocalRegion region) async {
    final root = ThermalTileStore.regionThermalRoot(region.directoryPath);
    final required = ThermalPrefetchPlanner.requiredVariants(_clock());
    final tiles = ThermalPrefetchPlanner.tiles(region.bounds).toList();
    final previous =
        _states[region.id] ?? RegionThermalState(regionId: region.id);

    final storedPerVariant = <String, int>{};
    final pending = <(ThermalVariant, int, int, int, File)>[];
    for (final v in required) {
      var stored = 0;
      for (final t in tiles) {
        final file = File(
          '$root/${ThermalTileStore.tileRelativePath(v, t.z, t.x, t.y)}',
        );
        if (await file.exists()) {
          stored++;
        } else {
          pending.add((v, t.z, t.x, t.y, file));
        }
      }
      storedPerVariant[v.key] = stored;
    }

    final total = tiles.length * required.length;
    var storedTotal = storedPerVariant.values.fold(0, (a, b) => a + b);
    var state = previous.copyWith(
      status: ThermalPrefetchStatus.inProgress,
      totalTiles: total,
      storedTiles: storedTotal,
      clearError: true,
    );
    _states[region.id] = state;
    _notify();

    String? abortReason;
    var failedTiles = 0;
    var cursor = 0;
    var sinceNotify = 0;

    Future<void> worker() async {
      while (abortReason == null && !_disposed && cursor < pending.length) {
        final (v, z, x, y, file) = pending[cursor++];
        try {
          final bytes = await _fetchWithRetry(
            Kk7Provider.tileUri(v, z, x, y, baseUrl: kk7BaseUrl),
          );
          if (bytes == null) {
            failedTiles++;
            continue;
          }
          await ThermalTileStore.writeAtomic(file, bytes);
          storedPerVariant[v.key] = storedPerVariant[v.key]! + 1;
          storedTotal++;
          if (++sinceNotify >= 25) {
            sinceNotify = 0;
            _states[region.id] = _states[region.id]!.copyWith(
              storedTiles: storedTotal,
            );
            _notify();
          }
        } on Kk7HttpException catch (e) {
          abortReason = 'KK7 unavailable (HTTP ${e.statusCode})';
        } on FileSystemException catch (e) {
          abortReason = 'Storage error: ${e.message}';
        } catch (e) {
          // SocketException, TimeoutException, HandshakeException, ...
          debugPrint(
            '[ThermalPrefetch] ${region.id}: network failure, pausing: $e',
          );
          abortReason = 'offline';
        }
      }
    }

    await Future.wait([for (var i = 0; i < maxConcurrent; i++) worker()]);

    final completeVariants = {
      ...previous.completeVariants.where(
        (k) => Directory('$root/$k').existsSync(),
      ),
    };
    for (final v in required) {
      if (storedPerVariant[v.key] == tiles.length) {
        completeVariants.add(v.key);
      } else {
        completeVariants.remove(v.key);
      }
    }
    final allComplete = required.every((v) => completeVariants.contains(v.key));
    if (allComplete) {
      await _pruneExcept(root, {for (final v in required) v.key});
      completeVariants.retainAll({for (final v in required) v.key});
    }

    final ThermalPrefetchStatus status;
    if (allComplete) {
      status = ThermalPrefetchStatus.complete;
    } else if (storedTotal == 0) {
      status = ThermalPrefetchStatus.failed;
    } else {
      status = ThermalPrefetchStatus.partial;
    }
    final error =
        abortReason ??
        (failedTiles > 0 ? '$failedTiles tiles could not be fetched' : null);

    state = RegionThermalState(
      regionId: region.id,
      status: status,
      totalTiles: total,
      storedTiles: storedTotal,
      bytes: await _directorySize(Directory(root)),
      completeVariants: completeVariants,
      updatedAt: _clock(),
      lastError: error,
    );
    _states[region.id] = state;
    await _writeState(root, state);
    store.invalidateRegionList();
    _notify();

    if (abortReason == 'offline') _scheduleOfflineRetry();
  }

  Future<Uint8List?> _fetchWithRetry(Uri uri) async {
    for (var attempt = 1; ; attempt++) {
      await _limiter.acquire();
      try {
        return await _fetch(uri);
      } on Kk7HttpException {
        if (attempt >= maxAttempts) rethrow;
        await _sleep(prefetchBackoff(attempt));
      }
    }
  }

  void _scheduleOfflineRetry() {
    if (_disposed) return;
    _offlineRetryTimer?.cancel();
    _offlineRetryTimer = Timer(offlineRetryDelay, () => runAutomatic());
  }

  Future<void> _pruneExcept(String root, Set<String> keep) async {
    final dir = Directory(root);
    if (!await dir.exists()) return;
    await for (final e in dir.list(followLinks: false)) {
      if (e is! Directory) continue;
      final key = e.path.split(Platform.pathSeparator).last;
      if (ThermalVariant.tryParseKey(key) != null && !keep.contains(key)) {
        try {
          await e.delete(recursive: true);
        } catch (err) {
          debugPrint('[ThermalPrefetch] prune of $key failed: $err');
        }
      }
    }
  }

  Future<RegionThermalState> _readState(LocalRegion region) async {
    final file = File(
      '${ThermalTileStore.regionThermalRoot(region.directoryPath)}/$stateFileName',
    );
    try {
      if (await file.exists()) {
        final json = jsonDecode(await file.readAsString());
        if (json is Map<String, dynamic>) {
          return RegionThermalState.fromJson(region.id, json);
        }
      }
    } catch (_) {}
    return RegionThermalState(regionId: region.id);
  }

  Future<void> _writeState(String root, RegionThermalState state) async {
    try {
      await ThermalTileStore.writeAtomic(
        File('$root/$stateFileName'),
        utf8.encode(jsonEncode(state.toJson())),
      );
    } catch (e) {
      debugPrint('[ThermalPrefetch] state write failed: $e');
    }
  }

  static Future<int> _directorySize(Directory dir) async {
    var total = 0;
    try {
      if (!await dir.exists()) return 0;
      await for (final e in dir.list(recursive: true)) {
        if (e is File && !e.path.endsWith(stateFileName)) {
          total += await e.length();
        }
      }
    } catch (_) {}
    return total;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _recheckTimer?.cancel();
    _offlineRetryTimer?.cancel();
    _queue.clear();
    _ownedClient?.close(force: true);
    super.dispose();
  }
}
