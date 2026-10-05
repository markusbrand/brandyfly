import 'dart:io';

import '../../domain/thermal/geo_bounds.dart';
import '../../services/pmtiles_reader.dart';

/// A downloaded map region and its geographic extent.
class LocalRegion {
  const LocalRegion({
    required this.id,
    required this.directoryPath,
    required this.bounds,
  });

  final String id;
  final String directoryPath;
  final GeoBounds bounds;

  @override
  String toString() => 'LocalRegion($id, $bounds)';
}

/// Lookup for catalog-provided bounds (wired up once the region download
/// manager exists). Returns null when the catalog does not know [regionId].
typedef CatalogBoundsLookup = GeoBounds? Function(String regionId);

/// Discovers downloaded regions under `{appSupport}/regions/<id>/map.pmtiles`
/// and resolves their bounding boxes: catalog metadata first, otherwise the
/// PMTiles v3 header of the region's map archive.
class RegionBoundsProvider {
  RegionBoundsProvider({required this.regionsBasePath, this.catalogBounds});

  /// Resolves `{appSupport}/regions`.
  final Future<String> Function() regionsBasePath;
  final CatalogBoundsLookup? catalogBounds;

  /// Lists all regions with a non-empty map archive and resolvable bounds.
  Future<List<LocalRegion>> listRegions() async {
    final base = Directory(await regionsBasePath());
    if (!await base.exists()) return const [];
    final regions = <LocalRegion>[];
    await for (final entry in base.list(followLinks: false)) {
      if (entry is! Directory) continue;
      final id = entry.path.split(Platform.pathSeparator).last;
      if (id.startsWith('.') || id.endsWith('.downloading')) continue;
      final bounds = await boundsFor(id, entry.path);
      if (bounds != null) {
        regions.add(
          LocalRegion(id: id, directoryPath: entry.path, bounds: bounds),
        );
      }
    }
    regions.sort((a, b) => a.id.compareTo(b.id));
    return regions;
  }

  /// Bounds of region [id] located at [directoryPath], or null when the
  /// region has no usable map archive.
  Future<GeoBounds?> boundsFor(String id, String directoryPath) async {
    final mapFile = File('$directoryPath/map.pmtiles');
    if (!await mapFile.exists() || await mapFile.length() < 127) return null;

    final fromCatalog = catalogBounds?.call(id);
    if (fromCatalog != null && fromCatalog.isValid) return fromCatalog;

    PMTilesReader? reader;
    try {
      reader = await PMTilesReader.open(mapFile);
      final h = reader.header;
      final bounds = GeoBounds(
        west: h.minLon,
        south: h.minLat,
        east: h.maxLon,
        north: h.maxLat,
      );
      return bounds.isValid ? bounds : null;
    } catch (_) {
      return null;
    } finally {
      await reader?.close();
    }
  }
}
