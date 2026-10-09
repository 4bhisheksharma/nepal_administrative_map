import 'dart:convert';
import 'dart:typed_data';

import '../../geometry/bounds.dart';
import '../../geometry/lat_lng.dart';
import '../../geometry/polygon.dart';
import '../../geometry/spatial_index.dart';
import '../gazetteer/nepal.dart';
import '../models/region.dart';
import '../topojson/topology.dart';
import 'background.dart';
import 'map_data_source.dart';

/// The outline of one region or protected area.
class MapShape<T> {
  MapShape._(this.feature, this.polygons, this.arcRefs)
    : bounds = Bounds.union([
        for (final p in polygons) Bounds.ofCoords(p.first),
      ]);

  /// The [Region] or [ProtectedArea] this shape belongs to.
  final T feature;

  /// Polygons → rings as interleaved `[lng, lat, …]`. Each polygon's first
  /// ring is its outer boundary; the rest are holes.
  final List<List<Float64List>> polygons;

  /// The same structure as [polygons], as indices into [NepalMapData.arcs].
  /// A negative index `~i` means arc `i` reversed.
  final List<List<List<int>>> arcRefs;

  /// Bounding box in degrees (x = longitude, y = latitude).
  final Bounds bounds;

  /// Whether [point] lies inside this shape.
  bool contains(LatLng point) =>
      bounds.contains(point.longitude, point.latitude) &&
      polygons.any((p) => polygonContains(p, point.longitude, point.latitude));
}

/// Decoded boundaries for every level, ready to draw and hit-test.
///
/// Load it with [load]; the result is cached, so every map in the app shares
/// one copy.
final class NepalMapData {
  NepalMapData._(
    this.arcs,
    this.provinces,
    this.districts,
    this.localLevels,
    this.protectedAreas,
  ) : bounds = Bounds.union(provinces.map((s) => s.bounds)),
      _byCode = {
        for (final s in <MapShape<Region>>[
          ...provinces,
          ...districts,
          ...localLevels,
        ])
          s.feature.code: s,
      },
      _indexes = {
        AdminLevel.province: SpatialIndex(
          provinces,
          (s) => s.bounds,
          cellsPerSide: 8,
        ),
        AdminLevel.district: SpatialIndex(districts, (s) => s.bounds),
        AdminLevel.localLevel: SpatialIndex(
          localLevels,
          (s) => s.bounds,
          cellsPerSide: 64,
        ),
      },
      _protectedIndex = SpatialIndex(
        protectedAreas,
        (s) => s.bounds,
        cellsPerSide: 8,
      );

  /// Parses TopoJSON text synchronously. Prefer [load], which does this in
  /// the background and caches the result.
  ///
  /// Throws [FormatException] if the data doesn't match the gazetteer.
  factory NepalMapData.parse(String json) {
    final topology = Topology.fromJson(
      jsonDecode(json) as Map<String, dynamic>,
    );

    List<MapShape<T>> shapes<T>(
      String object,
      T? Function(String code) lookup,
    ) {
      final geometries = topology.objects[object];
      if (geometries == null) throw FormatException('Missing object "$object"');
      return [
        for (final g in geometries)
          MapShape<T>._(
            lookup(g.id ?? '') ??
                (throw FormatException('Unknown code "${g.id}" in $object')),
            [
              for (final polygon in g.polygons)
                [for (final ring in polygon) topology.ring(ring)],
            ],
            g.polygons,
          ),
      ];
    }

    T? region<T extends Region>(String code) => switch (Nepal.byCode(code)) {
      final T r => r,
      _ => null,
    };

    return NepalMapData._(
      topology.arcs,
      shapes('provinces', region<Province>),
      shapes('districts', region<District>),
      shapes('local_levels', region<LocalLevel>),
      shapes('protected_areas', Nepal.protectedAreaByCode),
    );
  }

  static final _cache = <Object, Future<NepalMapData>>{};

  /// Loads and decodes [source] in the background (inline on the web).
  ///
  /// Sources with the same [MapDataSource.cacheKey] are loaded once; later
  /// calls return the same instance. A failed load is not cached.
  static Future<NepalMapData> load(MapDataSource source) {
    final key = source.cacheKey;
    return _cache[key] ??= () async {
      try {
        final json = await source.load();
        return await _parseInBackground(json);
      } catch (_) {
        _cache.removeWhere((k, _) => k == key);
        rethrow;
      }
    }();
  }

  // A separate function so the isolate's closure captures only the string.
  // A closure inside [load] would also capture the source, which may hold
  // objects that can't be sent between isolates (e.g. an asset bundle's
  // pending futures).
  static Future<NepalMapData> _parseInBackground(String json) =>
      runInBackground(() => NepalMapData.parse(json));

  /// Forgets every loaded copy. Mainly for tests.
  static void clearCache() => _cache.clear();

  /// Every border segment as `[lng, lat, …]`, shared between all levels.
  final List<Float64List> arcs;

  /// The 7 province shapes, in code order.
  final List<MapShape<Province>> provinces;

  /// The 77 district shapes, in code order.
  final List<MapShape<District>> districts;

  /// The 753 local-level shapes, in code order.
  final List<MapShape<LocalLevel>> localLevels;

  /// The 10 protected-area shapes, in code order.
  final List<MapShape<ProtectedArea>> protectedAreas;

  /// Bounds of the whole country, in degrees.
  final Bounds bounds;

  final Map<String, MapShape<Region>> _byCode;
  final Map<AdminLevel, SpatialIndex<MapShape<Region>>> _indexes;
  final SpatialIndex<MapShape<ProtectedArea>> _protectedIndex;

  /// The shapes for [level].
  List<MapShape<Region>> shapesOf(AdminLevel level) => switch (level) {
    AdminLevel.province => provinces,
    AdminLevel.district => districts,
    AdminLevel.localLevel => localLevels,
  };

  /// The shape of [region].
  MapShape<Region> shapeOf(Region region) => _byCode[region.code]!;

  /// The shape of [area].
  MapShape<ProtectedArea> protectedAreaShapeOf(ProtectedArea area) =>
      protectedAreas[area.index];

  /// The region at [level] containing [point], or `null` outside Nepal (or
  /// inside a protected area, at the local level).
  Region? regionAt(LatLng point, AdminLevel level) {
    for (final shape in _indexes[level]!.query(
      point.longitude,
      point.latitude,
    )) {
      if (shape.contains(point)) return shape.feature;
    }
    return null;
  }

  /// The protected area containing [point], if any.
  ProtectedArea? protectedAreaAt(LatLng point) {
    for (final shape in _protectedIndex.query(
      point.longitude,
      point.latitude,
    )) {
      if (shape.contains(point)) return shape.feature;
    }
    return null;
  }
}
