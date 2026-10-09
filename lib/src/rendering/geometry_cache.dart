import 'dart:typed_data';
import 'dart:ui';

import '../data/loader/nepal_map_data.dart';
import '../data/models/region.dart';
import 'map_plane.dart';

/// Which regions are shown: a level, optionally limited to one region.
typedef MapView = ({AdminLevel level, Region? scope});

/// Whether [region] lies inside [scope] (always true without a scope).
bool inScope(Region region, Region? scope) => switch (scope) {
  null => true,
  Province() => region.province == scope,
  District() => region is LocalLevel && region.district == scope,
  LocalLevel() => region == scope,
};

/// Arc paths for one [MapView].
class BorderPaths {
  BorderPaths._(this.inner, this.parent, this.outline);

  /// Borders between neighbouring regions at the shown level.
  final Path inner;

  /// Borders of coarser levels inside the view, e.g. province borders when
  /// showing districts.
  final Path parent;

  /// The outer edge of the view (the country, or the scope region).
  final Path outline;
}

/// Plane-space paths built once per [NepalMapData] and shared by every map.
///
/// Built lazily: a level's paths are created the first time it is shown.
class GeometryCache {
  GeometryCache._(this.data) : plane = MapPlane(data.bounds);

  static final _caches = Expando<GeometryCache>();

  /// The cache for [data].
  static GeometryCache of(NepalMapData data) =>
      _caches[data] ??= GeometryCache._(data);

  /// The decoded data.
  final NepalMapData data;

  /// The plane every path is in.
  final MapPlane plane;

  final _shapePaths = <String, Path>{};
  final _protectedPaths = <ProtectedArea, Path>{};
  final _protectedVisible = <MapView, List<ProtectedArea>>{};
  final _arcPaths = <int, Path>{};
  final _borders = <MapView, BorderPaths>{};
  final _visible = <MapView, List<Region>>{};

  /// Regions shown for [view], in code order.
  List<Region> regions(MapView view) => _visible[view] ??= List.unmodifiable(
    data
        .shapesOf(view.level)
        .map((s) => s.feature)
        .where((r) => inScope(r, view.scope)),
  );

  /// Protected areas to fill as background in [view]: on local-level maps
  /// they would otherwise be holes, since they belong to no local level.
  List<ProtectedArea> protectedAreas(MapView view) =>
      _protectedVisible[view] ??= view.level != AdminLevel.localLevel
      ? const []
      : List.unmodifiable(
          data.protectedAreas
              .map((s) => s.feature)
              .where(
                (area) => area.districts.any(
                  (d) => inScope(d, view.scope) || d == view.scope,
                ),
              ),
        );

  /// Fill path of [area].
  Path protectedAreaPath(ProtectedArea area) => _protectedPaths[area] ??=
      _polygonsPath(data.protectedAreaShapeOf(area).polygons);

  /// Plane rectangle to fit for [view].
  Rect contentRect(MapView view) => switch (view.scope) {
    null => plane.rect,
    final scope => plane.rectOf(data.shapeOf(scope).bounds),
  };

  /// Fill path of [region] (even-odd, so holes stay empty).
  Path pathOf(Region region) =>
      _shapePaths[region.code] ??= _buildShapePath(region);

  /// Border paths for [view].
  BorderPaths borders(MapView view) => _borders[view] ??= _buildBorders(view);

  Path _buildShapePath(Region region) =>
      _polygonsPath(data.shapeOf(region).polygons);

  Path _polygonsPath(List<List<Float64List>> polygons) {
    final path = Path()..fillType = PathFillType.evenOdd;
    for (final polygon in polygons) {
      for (final ring in polygon) {
        _addPolyline(path, plane.projectCoords(ring), close: true);
      }
    }
    return path;
  }

  BorderPaths _buildBorders(MapView view) {
    Map<int, int> usage(Iterable<Region> regions) {
      final counts = <int, int>{};
      for (final r in regions) {
        for (final polygon in data.shapeOf(r).arcRefs) {
          for (final ring in polygon) {
            for (final ref in ring) {
              final arc = ref < 0 ? ~ref : ref;
              counts[arc] = (counts[arc] ?? 0) + 1;
            }
          }
        }
      }
      return counts;
    }

    final own = usage(regions(view));
    final parentArcs = <int>{
      for (final level in AdminLevel.values.take(view.level.index))
        for (final MapEntry(:key, :value) in usage(
          data
              .shapesOf(level)
              .map((s) => s.feature)
              .where((r) => inScope(r, view.scope)),
        ).entries)
          if (value > 1) key,
    };

    final inner = Path(), parent = Path(), outline = Path();
    for (final MapEntry(key: arc, value: count) in own.entries) {
      final target = count == 1
          ? outline
          : (parentArcs.contains(arc) ? parent : inner);
      target.addPath(_arcPath(arc), Offset.zero);
    }
    return BorderPaths._(inner, parent, outline);
  }

  Path _arcPath(int arc) => _arcPaths[arc] ??= _addPolyline(
    Path(),
    plane.projectCoords(data.arcs[arc]),
    close: false,
  );

  static Path _addPolyline(Path path, Float64List xy, {required bool close}) {
    path.moveTo(xy[0], xy[1]);
    for (var i = 2; i < xy.length; i += 2) {
      path.lineTo(xy[i], xy[i + 1]);
    }
    if (close) path.close();
    return path;
  }
}
