import 'dart:math' as math;
import 'dart:typed_data';

import 'bounds.dart';
import 'polygon.dart';

/// The pole of inaccessibility: the point inside a polygon farthest from its
/// edges. A better label position than the centroid, which can fall outside
/// a curved or hollow shape.
///
/// [rings] is the outer ring followed by holes, as interleaved `[x, y, …]`.
/// [precision] is in the same units; it defaults to 1/1000 of the polygon's
/// larger side. `distance` is how far the point is from the nearest edge.
///
/// Port of Mapbox's polylabel (ISC license).
({double x, double y, double distance}) polylabel(
  List<Float64List> rings, {
  double? precision,
}) {
  final b = Bounds.ofCoords(rings.first);
  final cellSize = math.min(b.width, b.height);
  if (cellSize == 0) return (x: b.minX, y: b.minY, distance: 0);
  final tolerance = precision ?? math.max(b.width, b.height) / 1000;

  final queue = _MaxHeap();
  final h = cellSize / 2;
  for (var x = b.minX; x < b.maxX; x += cellSize) {
    for (var y = b.minY; y < b.maxY; y += cellSize) {
      queue.push(_Cell(x + h, y + h, h, rings));
    }
  }

  final c = ringCentroid(rings.first);
  var best = _Cell(c.x, c.y, 0, rings);
  final boxCenter = _Cell(
    b.minX + b.width / 2,
    b.minY + b.height / 2,
    0,
    rings,
  );
  if (boxCenter.d > best.d) best = boxCenter;

  while (queue.isNotEmpty) {
    final cell = queue.pop();
    if (cell.d > best.d) best = cell;
    if (cell.max - best.d <= tolerance) continue;
    final q = cell.h / 2;
    queue
      ..push(_Cell(cell.x - q, cell.y - q, q, rings))
      ..push(_Cell(cell.x + q, cell.y - q, q, rings))
      ..push(_Cell(cell.x - q, cell.y + q, q, rings))
      ..push(_Cell(cell.x + q, cell.y + q, q, rings));
  }
  return (x: best.x, y: best.y, distance: best.d);
}

class _Cell {
  _Cell(this.x, this.y, this.h, List<Float64List> rings)
    : d = _signedDistance(x, y, rings),
      max = 0 {
    max = d + h * math.sqrt2;
  }

  final double x, y, h, d;
  double max;
}

/// Distance from (x, y) to the polygon's nearest edge; negative outside.
double _signedDistance(double x, double y, List<Float64List> rings) {
  var minSq = double.infinity;
  for (final ring in rings) {
    final n = ring.length;
    for (var i = 0, j = n - 2; i < n; j = i, i += 2) {
      minSq = math.min(
        minSq,
        _segmentDistanceSq(x, y, ring[i], ring[i + 1], ring[j], ring[j + 1]),
      );
    }
  }
  final d = math.sqrt(minSq);
  return polygonContains(rings, x, y) ? d : -d;
}

double _segmentDistanceSq(
  double px,
  double py,
  double ax,
  double ay,
  double bx,
  double by,
) {
  var x = ax, y = ay;
  final dx = bx - ax, dy = by - ay;
  if (dx != 0 || dy != 0) {
    final t = ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy);
    if (t > 1) {
      x = bx;
      y = by;
    } else if (t > 0) {
      x += dx * t;
      y += dy * t;
    }
  }
  return (px - x) * (px - x) + (py - y) * (py - y);
}

/// Binary max-heap of cells ordered by their potential [_Cell.max].
class _MaxHeap {
  final _items = <_Cell>[];

  bool get isNotEmpty => _items.isNotEmpty;

  void push(_Cell cell) {
    _items.add(cell);
    var i = _items.length - 1;
    while (i > 0) {
      final parent = (i - 1) >> 1;
      if (_items[parent].max >= _items[i].max) break;
      _swap(i, parent);
      i = parent;
    }
  }

  _Cell pop() {
    final top = _items.first;
    final last = _items.removeLast();
    if (_items.isNotEmpty) {
      _items[0] = last;
      var i = 0;
      while (true) {
        final l = 2 * i + 1, r = l + 1;
        var largest = i;
        if (l < _items.length && _items[l].max > _items[largest].max) {
          largest = l;
        }
        if (r < _items.length && _items[r].max > _items[largest].max) {
          largest = r;
        }
        if (largest == i) break;
        _swap(i, largest);
        i = largest;
      }
    }
    return top;
  }

  void _swap(int a, int b) {
    final t = _items[a];
    _items[a] = _items[b];
    _items[b] = t;
  }
}
