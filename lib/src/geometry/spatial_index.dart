import 'bounds.dart';

/// A uniform grid over item bounding boxes, for fast point lookups.
///
/// [query] returns only the few items whose bounds contain the point; the
/// caller then runs the exact (and slower) point-in-polygon test on those.
class SpatialIndex<T> {
  /// Indexes [items] using [boundsOf], on a grid of [cellsPerSide]².
  SpatialIndex(
    List<T> items,
    Bounds Function(T item) boundsOf, {
    int cellsPerSide = 32,
  }) : _items = items,
       _bounds = [for (final item in items) boundsOf(item)],
       _n = cellsPerSide,
       _cells = List.generate(cellsPerSide * cellsPerSide, (_) => <int>[]),
       extent = items.isEmpty
           ? const Bounds(0, 0, 0, 0)
           : Bounds.union(items.map(boundsOf)) {
    for (var i = 0; i < _items.length; i++) {
      final b = _bounds[i];
      for (var cy = _cellY(b.minY); cy <= _cellY(b.maxY); cy++) {
        for (var cx = _cellX(b.minX); cx <= _cellX(b.maxX); cx++) {
          _cells[cy * _n + cx].add(i);
        }
      }
    }
  }

  final List<T> _items;
  final List<Bounds> _bounds;
  final int _n;
  final List<List<int>> _cells;

  /// Bounds of all indexed items.
  final Bounds extent;

  /// Items whose bounds contain (x, y).
  Iterable<T> query(double x, double y) sync* {
    if (_items.isEmpty || !extent.contains(x, y)) return;
    for (final i in _cells[_cellY(y) * _n + _cellX(x)]) {
      if (_bounds[i].contains(x, y)) yield _items[i];
    }
  }

  int _cellX(double x) => _cell(x, extent.minX, extent.width);
  int _cellY(double y) => _cell(y, extent.minY, extent.height);

  int _cell(double v, double min, double size) =>
      size == 0 ? 0 : ((v - min) / size * _n).floor().clamp(0, _n - 1);
}
