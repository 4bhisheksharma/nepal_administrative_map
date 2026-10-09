import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:nepal_administrative_map/core.dart';

final asset = MapDataSource.callback(
  'test-asset',
  () => File('assets/maps/nepal.topo.json').readAsString(),
);

void main() {
  late NepalMapData data;

  setUpAll(() async {
    final watch = Stopwatch()..start();
    data = await NepalMapData.load(asset);
    // Rough check against the < 300 ms budget (includes isolate start-up).
    printOnFailure('Load + decode: ${watch.elapsedMilliseconds} ms');
  });

  test('every feature resolves to a region', () {
    expect(data.provinces, hasLength(7));
    expect(data.districts, hasLength(77));
    expect(data.localLevels, hasLength(753));
    expect(data.protectedAreas, hasLength(10));
    expect(
      data.localLevels.map((s) => s.feature).toSet(),
      LocalLevel.values.toSet(),
    );
    expect(data.shapeOf(District.kaski).feature, District.kaski);
    expect(
      data.protectedAreaShapeOf(ProtectedArea.chitwan).feature,
      ProtectedArea.chitwan,
    );
  });

  test('country bounds match the source data', () {
    expect(data.bounds.minX, closeTo(80.06, 0.01));
    expect(data.bounds.maxX, closeTo(88.20, 0.01));
    expect(data.bounds.minY, closeTo(26.35, 0.01));
    expect(data.bounds.maxY, closeTo(30.47, 0.01));
  });

  group('regionAt', () {
    test('landmarks', () {
      const durbarSquare = LatLng(27.7043, 85.3070);
      expect(
        data.regionAt(durbarSquare, AdminLevel.localLevel),
        LocalLevel.kathmandu,
      );
      expect(
        data.regionAt(durbarSquare, AdminLevel.district),
        District.kathmandu,
      );
      expect(
        data.regionAt(durbarSquare, AdminLevel.province),
        Province.bagmati,
      );

      const phewaLake = LatLng(28.2156, 83.9450);
      expect(
        data.regionAt(phewaLake, AdminLevel.localLevel),
        LocalLevel.pokhara,
      );

      const patanDurbarSquare = LatLng(27.6727, 85.3253);
      expect(
        data.regionAt(patanDurbarSquare, AdminLevel.localLevel),
        LocalLevel.lalitpur,
      );
    });

    test('outside Nepal', () {
      const patna = LatLng(25.5941, 85.1376);
      for (final level in AdminLevel.values) {
        expect(data.regionAt(patna, level), isNull);
      }
    });

    test('protected areas', () {
      const chitwanNationalPark = LatLng(27.50, 84.20);
      expect(data.protectedAreaAt(chitwanNationalPark), ProtectedArea.chitwan);
      expect(data.regionAt(chitwanNationalPark, AdminLevel.localLevel), isNull);
      expect(
        data.regionAt(chitwanNationalPark, AdminLevel.district),
        District.chitwan,
      );
      expect(data.protectedAreaAt(const LatLng(27.7043, 85.3070)), isNull);
    });

    test('Madi, a municipality surrounded by Chitwan National Park', () {
      const madi = LatLng(27.45, 84.30);
      expect(
        data.regionAt(madi, AdminLevel.localLevel),
        LocalLevel.madiChitwan,
      );
      expect(data.protectedAreaAt(madi), isNull);
    });

    test('22 towns resolve to their local levels', () {
      const towns = [
        (LatLng(27.7043, 85.3070), LocalLevel.kathmandu),
        (LatLng(27.6727, 85.3253), LocalLevel.lalitpur),
        (LatLng(27.6721, 85.4281), LocalLevel.bhaktapur),
        (LatLng(28.2156, 83.9450), LocalLevel.pokhara),
        (LatLng(26.4525, 87.2718), LocalLevel.biratnagar),
        (LatLng(27.0104, 84.8770), LocalLevel.birgunj),
        (LatLng(27.6833, 84.4333), LocalLevel.bharatpur),
        (LatLng(27.7006, 83.4483), LocalLevel.butwal),
        (LatLng(28.0500, 81.6167), LocalLevel.nepalgunj),
        (LatLng(28.6833, 80.6000), LocalLevel.dhangadhi),
        (LatLng(26.8125, 87.2836), LocalLevel.dharan),
        (LatLng(27.4167, 85.0333), LocalLevel.hetauda),
        (LatLng(26.7288, 85.9263), LocalLevel.janakpur),
        (LatLng(26.6646, 87.2718), LocalLevel.itahari),
        (LatLng(28.0333, 82.4833), LocalLevel.ghorahi),
        (LatLng(28.1306, 82.2972), LocalLevel.tulsipur),
        (LatLng(28.6019, 81.6339), LocalLevel.birendranagar),
        (LatLng(28.9634, 80.1781), LocalLevel.bhimdatta),
        (LatLng(26.6595, 87.6983), LocalLevel.damak),
        (LatLng(28.0000, 84.6333), LocalLevel.gorkha),
        (
          LatLng(27.8069, 86.7140),
          LocalLevel.khumbupasanglahmu,
        ), // Namche Bazaar
        (LatLng(28.7804, 83.7220), LocalLevel.gharapjhong), // Jomsom
      ];
      for (final (point, expected) in towns) {
        expect(data.localLevelAt(point), expected, reason: '$point');
        expect(data.districtAt(point), expected.district);
        expect(data.provinceAt(point), expected.province);
      }
    });

    test('areas match official figures within 1%', () {
      final total = data.districts.fold(0.0, (sum, s) => sum + s.areaKm2);
      expect(total, closeTo(147516, 147516 * 0.01));
      expect(
        data.shapeOf(District.kathmandu).areaKm2,
        closeTo(413, 413 * 0.01),
      );
    });

    test('matches a brute-force search for 1,000 random points', () {
      final random = math.Random(42);
      final b = data.bounds;
      for (var i = 0; i < 1000; i++) {
        final p = LatLng(
          b.minY + random.nextDouble() * b.height,
          b.minX + random.nextDouble() * b.width,
        );
        for (final level in AdminLevel.values) {
          final brute = data
              .shapesOf(level)
              .where((s) => s.contains(p))
              .map((s) => s.feature);
          expect(
            data.regionAt(p, level),
            brute.firstOrNull,
            reason: '$p at $level',
          );
          expect(
            brute.length,
            lessThanOrEqualTo(1),
            reason: 'overlapping shapes at $p',
          );
        }
      }
    });
  });

  group('loading', () {
    test('a second load returns the cached instance', () async {
      expect(await NepalMapData.load(asset), same(data));
      final sameKey = MapDataSource.callback(
        'test-asset',
        () => throw StateError('not called'),
      );
      expect(await NepalMapData.load(sameKey), same(data));
    });

    test('a failed load is not cached', () async {
      var calls = 0;
      final flaky = MapDataSource.callback('flaky', () async {
        if (calls++ == 0) throw const FileSystemException('first try fails');
        return File('assets/maps/nepal.topo.json').readAsString();
      });
      await expectLater(
        NepalMapData.load(flaky),
        throwsA(isA<FileSystemException>()),
      );
      expect(await NepalMapData.load(flaky), isA<NepalMapData>());
      expect(calls, 2);
    });

    test(
      'works when the source holds objects that cannot cross isolates',
      () async {
        // Regression: the isolate closure used to capture the source, so a
        // source holding e.g. a pending Future failed to load.
        final source = _SourceWithFuture();
        expect(await NepalMapData.load(source), isA<NepalMapData>());
      },
    );

    test('rejects data that does not match the gazetteer', () {
      const json =
          '{"type":"Topology","arcs":[],"objects":{"provinces":'
          '{"type":"GeometryCollection","geometries":[{"type":"Polygon","id":"P99","arcs":[]}]}}}';
      expect(() => NepalMapData.parse(json), throwsFormatException);
    });
  });
}

class _SourceWithFuture extends MapDataSource {
  final pending = Completer<void>().future;

  @override
  Object get cacheKey => this;

  @override
  Future<String> load() => File('assets/maps/nepal.topo.json').readAsString();
}
