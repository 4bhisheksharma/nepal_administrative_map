import 'dart:math' as math;
import 'dart:typed_data';

/// An axis-aligned rectangle in planar coordinates.
///
/// For geographic data, x is longitude and y is latitude.
class Bounds {
  /// Creates bounds from its edges.
  const Bounds(this.minX, this.minY, this.maxX, this.maxY);

  /// Bounds of interleaved `[x0, y0, x1, y1, …]` coordinates.
  factory Bounds.ofCoords(Float64List coords) {
    var minX = double.infinity, minY = double.infinity;
    var maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (var i = 0; i < coords.length; i += 2) {
      final x = coords[i], y = coords[i + 1];
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
    return Bounds(minX, minY, maxX, maxY);
  }

  /// The smallest bounds containing all of [bounds].
  factory Bounds.union(Iterable<Bounds> bounds) =>
      bounds.reduce((a, b) => a.expand(b));

  /// Left edge.
  final double minX;

  /// Bottom edge (south, for geographic data).
  final double minY;

  /// Right edge.
  final double maxX;

  /// Top edge (north, for geographic data).
  final double maxY;

  /// `maxX - minX`.
  double get width => maxX - minX;

  /// `maxY - minY`.
  double get height => maxY - minY;

  /// Whether the point lies inside or on the edge.
  bool contains(double x, double y) =>
      x >= minX && x <= maxX && y >= minY && y <= maxY;

  /// Whether the two rectangles overlap (touching counts).
  bool intersects(Bounds other) =>
      other.minX <= maxX &&
      other.maxX >= minX &&
      other.minY <= maxY &&
      other.maxY >= minY;

  /// The smallest bounds containing this and [other].
  Bounds expand(Bounds other) => Bounds(
    math.min(minX, other.minX),
    math.min(minY, other.minY),
    math.max(maxX, other.maxX),
    math.max(maxY, other.maxY),
  );

  @override
  bool operator ==(Object other) =>
      other is Bounds &&
      other.minX == minX &&
      other.minY == minY &&
      other.maxX == maxX &&
      other.maxY == maxY;

  @override
  int get hashCode => Object.hash(minX, minY, maxX, maxY);

  @override
  String toString() => 'Bounds($minX, $minY, $maxX, $maxY)';
}
