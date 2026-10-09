import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nepal_administrative_map/nepal_administrative_map.dart';

void main() {
  const black = Color(0xFF000000),
      white = Color(0xFFFFFFFF),
      red = Color(0xFFFF0000),
      blue = Color(0xFF0000FF);
  const extent = (min: 0, max: 100);

  group('sequential', () {
    const scale = ColorScale.sequential(black, white);

    test('domain edges and clamping', () {
      expect(scale.colorOf(0, extent), black);
      expect(scale.colorOf(100, extent), white);
      expect(scale.colorOf(-50, extent), black);
      expect(scale.colorOf(500, extent), white);
    });

    test('midpoint is perceptually grey, not RGB 50%', () {
      final mid = scale.colorOf(50, extent)!;
      expect(mid.r, closeTo(mid.g, 1e-6));
      // OKLab's perceptual midpoint is darker than linear sRGB 50% (0.5).
      expect(mid.r, inInclusiveRange(0.35, 0.5));
    });

    test('explicit domain overrides the data extent', () {
      const fixed = ColorScale.sequential(
        black,
        white,
        domain: (min: 0, max: 10),
      );
      expect(fixed.colorOf(10, extent), white);
    });

    test('no data', () {
      expect(scale.colorOf(null, extent), isNull);
      expect(scale.colorOf('x', extent), isNull);
      expect(scale.colorOf(double.nan, extent), isNull);
    });

    test('flat data gets the middle colour', () {
      expect(scale.colorOf(5, (min: 5, max: 5)), scale.colorOf(50, extent));
    });
  });

  test('diverging hits mid exactly at the midpoint', () {
    const scale = ColorScale.diverging(blue, white, red, midpoint: 20);
    expect(scale.colorOf(20, extent), white);
    expect(scale.colorOf(0, extent), blue);
    expect(scale.colorOf(100, extent), red);
    expect((scale as DivergingScale).midOf(extent), 20);
    expect(
      (const ColorScale.diverging(blue, white, red) as DivergingScale).midOf(
        extent,
      ),
      50,
    );
  });

  test('threshold steps', () {
    final scale = ColorScale.threshold([10, 50], [black, blue, red]);
    expect(scale.colorOf(9.9, extent), black);
    expect(scale.colorOf(10, extent), blue);
    expect(scale.colorOf(49, extent), blue);
    expect(scale.colorOf(50, extent), red);
    expect(() => ColorScale.threshold([10], [black]), throwsAssertionError);
  });

  test('categorical', () {
    const scale = ColorScale.categorical({'a': red, 'b': blue});
    expect(scale.colorOf('a', extent), red);
    expect(scale.colorOf('c', extent), isNull);
  });

  test('extentOf ignores non-numbers', () {
    expect(ColorScale.extentOf([3, null, 'x', 1, double.nan, 7]), (
      min: 1,
      max: 7,
    ));
    expect(ColorScale.extentOf(['x']), isNull);
  });
}
