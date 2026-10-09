import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nepal_administrative_map/src/data/topojson/topology.dart';

void main() {
  // Two unit squares side by side sharing the edge x=1. Quantized with
  // scale 1 and translate (10, 20), delta-encoded.
  //   arc 0: shared edge (1,0) → (1,1)
  //   arc 1: left square's other three sides (1,1) → (0,1) → (0,0) → (1,0)
  //   arc 2: right square's other three sides (1,0) → (2,0) → (2,1) → (1,1)
  final json = {
    'type': 'Topology',
    'transform': {
      'scale': [1, 1],
      'translate': [10, 20],
    },
    'arcs': [
      [
        [1, 0],
        [0, 1],
      ],
      [
        [1, 1],
        [-1, 0],
        [0, -1],
        [1, 0],
      ],
      [
        [1, 0],
        [1, 0],
        [0, 1],
        [-1, 0],
      ],
    ],
    'objects': {
      'squares': {
        'type': 'GeometryCollection',
        'geometries': [
          {
            'type': 'Polygon',
            'id': 'left',
            'arcs': [
              [0, 1],
            ],
          },
          {
            'type': 'MultiPolygon',
            'id': 'right',
            'arcs': [
              [
                [-1, 2],
              ],
            ],
          },
        ],
      },
    },
  };

  test('decodes quantized, delta-encoded arcs', () {
    final t = Topology.fromJson(json);
    expect(t.arcs[0], Float64List.fromList([11, 20, 11, 21]));
    expect(t.arcs[1], Float64List.fromList([11, 21, 10, 21, 10, 20, 11, 20]));
  });

  test('joins arcs into rings, dropping shared endpoints', () {
    final t = Topology.fromJson(json);
    final left = t.objects['squares']![0];
    expect(left.id, 'left');
    expect(
      t.ring(left.polygons.single.single),
      Float64List.fromList([11, 20, 11, 21, 10, 21, 10, 20, 11, 20]),
    );
  });

  test('negative arc index reverses the arc', () {
    final t = Topology.fromJson(json);
    final right = t.objects['squares']![1];
    expect(right.polygons, hasLength(1));
    expect(
      t.ring(right.polygons.single.single),
      Float64List.fromList([11, 21, 11, 20, 12, 20, 12, 21, 11, 21]),
    );
  });

  test('rejects non-topologies', () {
    expect(
      () => Topology.fromJson({'type': 'FeatureCollection'}),
      throwsFormatException,
    );
  });
}
