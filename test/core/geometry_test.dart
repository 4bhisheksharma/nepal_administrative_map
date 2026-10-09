import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nepal_administrative_map/core.dart';
import 'package:nepal_administrative_map/src/geometry/spatial_index.dart';

Float64List coords(List<double> c) => Float64List.fromList(c);

void main() {
  // 10×10 square with a 2×2 hole in the middle.
  final square = coords([0, 0, 10, 0, 10, 10, 0, 10, 0, 0]);
  final hole = coords([4, 4, 4, 6, 6, 6, 6, 4, 4, 4]);

  test('Bounds', () {
    final b = Bounds.ofCoords(square);
    expect(b, const Bounds(0, 0, 10, 10));
    expect(b.contains(5, 5), isTrue);
    expect(b.contains(11, 5), isFalse);
    expect(b.intersects(const Bounds(9, 9, 20, 20)), isTrue);
    expect(b.intersects(const Bounds(11, 11, 20, 20)), isFalse);
    expect(b.expand(const Bounds(-1, 2, 3, 12)), const Bounds(-1, 0, 10, 12));
  });

  test('area and centroid', () {
    expect(ringSignedArea(square).abs(), 100);
    expect(polygonArea([square, hole]), 96);
    final c = ringCentroid(square);
    expect(c.x, closeTo(5, 1e-9));
    expect(c.y, closeTo(5, 1e-9));
  });

  test('point in polygon excludes holes', () {
    expect(polygonContains([square, hole], 2, 2), isTrue);
    expect(polygonContains([square, hole], 5, 5), isFalse);
    expect(polygonContains([square, hole], 11, 5), isFalse);
  });

  test('Web Mercator round trip', () {
    const kathmandu = LatLng(27.7172, 85.3240);
    final p = WebMercator.project(kathmandu);
    expect(p.x, closeTo((85.3240 + 180) / 360, 1e-12));
    expect(p.y, lessThan(0.5)); // north of the equator is above the middle
    final back = WebMercator.unproject(p.x, p.y);
    expect(back.latitude, closeTo(kathmandu.latitude, 1e-9));
    expect(back.longitude, closeTo(kathmandu.longitude, 1e-9));
    expect(WebMercator.project(const LatLng(0, 0)), (x: 0.5, y: 0.5));
  });

  group('polylabel', () {
    test('centre of a square', () {
      final p = polylabel([square], precision: 0.01);
      expect(p.x, closeTo(5, 0.05));
      expect(p.y, closeTo(5, 0.05));
      expect(p.distance, closeTo(5, 0.05));
    });

    test('avoids the hole', () {
      final p = polylabel([square, hole], precision: 0.01);
      expect(polygonContains([square, hole], p.x, p.y), isTrue);
      expect(p.distance, greaterThan(1.9));
    });

    test('stays inside an L shape, where the centroid does not', () {
      final l = coords([0, 0, 10, 0, 10, 1, 1, 1, 1, 10, 0, 10, 0, 0]);
      final c = ringCentroid(l);
      expect(polygonContains([l], c.x, c.y), isFalse);
      final p = polylabel([l]);
      expect(polygonContains([l], p.x, p.y), isTrue);
    });
  });

  test('SpatialIndex returns only items whose bounds contain the point', () {
    final boxes = [
      const Bounds(0, 0, 1, 1),
      const Bounds(0.5, 0.5, 2, 2),
      const Bounds(5, 5, 6, 6),
    ];
    final index = SpatialIndex(
      List.generate(boxes.length, (i) => i),
      (i) => boxes[i],
      cellsPerSide: 4,
    );
    expect(index.query(0.75, 0.75).toSet(), {0, 1});
    expect(index.query(5.5, 5.5).toList(), [2]);
    expect(index.query(3, 3), isEmpty);
    expect(index.query(-1, -1), isEmpty);
  });
}
