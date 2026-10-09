import 'dart:typed_data';

/// A decoded TopoJSON topology.
///
/// Arcs are decoded once (quantization and delta encoding undone) into
/// absolute `[lng, lat, …]` coordinates. Geometries keep their arc indices so
/// shared borders can be drawn once, from the arcs.
class Topology {
  Topology._(this.arcs, this.objects);

  /// Decodes a parsed TopoJSON document.
  ///
  /// Supports `Polygon` and `MultiPolygon` geometries, which is all the
  /// package's data contains. Throws [FormatException] on anything else.
  factory Topology.fromJson(Map<String, dynamic> json) {
    if (json['type'] != 'Topology') {
      throw const FormatException('Not a TopoJSON topology');
    }
    final transform = json['transform'] as Map<String, dynamic>?;
    final arcs = [
      for (final arc in json['arcs'] as List)
        _decodeArc(arc as List, transform),
    ];
    final objects = <String, List<TopoGeometry>>{};
    for (final MapEntry(:key, :value)
        in (json['objects'] as Map<String, dynamic>).entries) {
      final collection = value as Map<String, dynamic>;
      objects[key] = [
        for (final g in collection['geometries'] as List)
          TopoGeometry._fromJson(g as Map<String, dynamic>),
      ];
    }
    return Topology._(arcs, objects);
  }

  /// Every arc as interleaved absolute `[lng, lat, …]` coordinates.
  final List<Float64List> arcs;

  /// Geometries of each named object, e.g. `objects['districts']`.
  final Map<String, List<TopoGeometry>> objects;

  /// Joins arcs into one ring. A negative index `~i` means arc `i` reversed.
  Float64List ring(List<int> arcRefs) {
    var length = 0;
    for (final ref in arcRefs) {
      length += arcs[ref < 0 ? ~ref : ref].length - 2;
    }
    // Consecutive arcs share an endpoint; only the first arc keeps its start.
    final out = Float64List(length + 2);
    var o = 0;
    for (final (k, ref) in arcRefs.indexed) {
      final arc = arcs[ref < 0 ? ~ref : ref];
      final points = arc.length ~/ 2;
      for (var p = k == 0 ? 0 : 1; p < points; p++) {
        final src = ref < 0 ? points - 1 - p : p;
        out[o++] = arc[src * 2];
        out[o++] = arc[src * 2 + 1];
      }
    }
    return out;
  }

  static Float64List _decodeArc(
    List<dynamic> arc,
    Map<String, dynamic>? transform,
  ) {
    final out = Float64List(arc.length * 2);
    if (transform == null) {
      for (var i = 0; i < arc.length; i++) {
        final p = arc[i] as List;
        out[i * 2] = (p[0] as num).toDouble();
        out[i * 2 + 1] = (p[1] as num).toDouble();
      }
      return out;
    }
    final scale = transform['scale'] as List;
    final translate = transform['translate'] as List;
    final sx = (scale[0] as num).toDouble(), sy = (scale[1] as num).toDouble();
    final tx = (translate[0] as num).toDouble(),
        ty = (translate[1] as num).toDouble();
    var x = 0, y = 0;
    for (var i = 0; i < arc.length; i++) {
      final p = arc[i] as List;
      x += p[0] as int;
      y += p[1] as int;
      out[i * 2] = x * sx + tx;
      out[i * 2 + 1] = y * sy + ty;
    }
    return out;
  }
}

/// One polygon or multipolygon geometry, as arc indices.
class TopoGeometry {
  TopoGeometry._(this.id, this.polygons);

  factory TopoGeometry._fromJson(Map<String, dynamic> json) {
    List<List<int>> polygon(List<dynamic> rings) => [
      for (final ring in rings) [for (final i in ring as List) i as int],
    ];
    final arcs = json['arcs'] as List;
    return switch (json['type']) {
      'Polygon' => TopoGeometry._(json['id'] as String?, [polygon(arcs)]),
      'MultiPolygon' => TopoGeometry._(json['id'] as String?, [
        for (final p in arcs) polygon(p as List),
      ]),
      final type => throw FormatException('Unsupported geometry type: $type'),
    };
  }

  /// The feature's id (the region code in this package's data).
  final String? id;

  /// Polygons → rings → arc indices. Each polygon's first ring is the outer
  /// boundary; the rest are holes.
  final List<List<List<int>>> polygons;
}
