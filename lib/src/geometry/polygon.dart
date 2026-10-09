import 'dart:math' as math;
import 'dart:typed_data';

// Helpers for rings stored as interleaved `[x0, y0, x1, y1, …]` coordinates.
// A polygon is a list of rings: the outer ring first, then any holes.

/// Signed area of a ring (shoelace formula). The sign depends on winding
/// order and on whether y grows up or down; use `.abs()` for the size.
double ringSignedArea(Float64List ring) {
  var sum = 0.0;
  final n = ring.length;
  for (var i = 0, j = n - 2; i < n; j = i, i += 2) {
    sum += (ring[j] - ring[i]) * (ring[j + 1] + ring[i + 1]);
  }
  return sum / 2;
}

/// Area of a polygon: the outer ring minus its holes.
double polygonArea(List<Float64List> rings) {
  var area = ringSignedArea(rings.first).abs();
  for (final hole in rings.skip(1)) {
    area -= ringSignedArea(hole).abs();
  }
  return area;
}

/// Area-weighted centroid of a ring. Falls back to the first point for a
/// degenerate (zero-area) ring.
({double x, double y}) ringCentroid(Float64List ring) {
  var cx = 0.0, cy = 0.0, area = 0.0;
  final n = ring.length;
  for (var i = 0, j = n - 2; i < n; j = i, i += 2) {
    final f = ring[j] * ring[i + 1] - ring[i] * ring[j + 1];
    cx += (ring[j] + ring[i]) * f;
    cy += (ring[j + 1] + ring[i + 1]) * f;
    area += f * 3;
  }
  if (area == 0) return (x: ring[0], y: ring[1]);
  return (x: cx / area, y: cy / area);
}

/// Whether (x, y) lies inside the polygon, using the even-odd rule so holes
/// are excluded. Points exactly on an edge may go either way.
bool polygonContains(List<Float64List> rings, double x, double y) {
  var inside = false;
  for (final ring in rings) {
    final n = ring.length;
    for (var i = 0, j = n - 2; i < n; j = i, i += 2) {
      final xi = ring[i], yi = ring[i + 1];
      final xj = ring[j], yj = ring[j + 1];
      if ((yi > y) != (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) {
        inside = !inside;
      }
    }
  }
  return inside;
}

/// Earth's radius used for areas, in metres (WGS84 equatorial).
const double earthRadiusMeters = 6378137;

/// Area of a polygon on the sphere, in square metres, for rings given as
/// interleaved `[lng, lat, …]` degrees. The outer ring minus its holes.
double geodesicArea(List<Float64List> rings) {
  double ring(Float64List r) {
    var sum = 0.0;
    const toRad = 3.141592653589793 / 180;
    for (var i = 0, j = r.length - 2; i < r.length; j = i, i += 2) {
      sum +=
          (r[i] - r[j]) *
          toRad *
          (2 + _sin(r[j + 1] * toRad) + _sin(r[i + 1] * toRad));
    }
    return (sum * earthRadiusMeters * earthRadiusMeters / 2).abs();
  }

  var area = ring(rings.first);
  for (final hole in rings.skip(1)) {
    area -= ring(hole);
  }
  return area;
}

double _sin(double x) => math.sin(x);
