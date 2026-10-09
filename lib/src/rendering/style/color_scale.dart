import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../../i18n/localized_name.dart';

/// The numeric range a continuous scale maps onto its colours.
typedef ScaleDomain = ({num min, num max});

/// Maps data values to colours for a choropleth map and its legend.
///
/// ```dart
/// ColorScale.sequential(Colors.yellow.shade100, Colors.red.shade900)
/// ColorScale.diverging(Colors.blue, Colors.white, Colors.red, midpoint: 0)
/// ColorScale.threshold([1000, 5000], [Colors.green, Colors.yellow, Colors.red])
/// ColorScale.categorical({'A': Colors.teal, 'B': Colors.orange})
/// ```
///
/// Continuous scales interpolate in OKLab, so equal steps in value look like
/// equal steps in colour.
sealed class ColorScale {
  const ColorScale();

  /// From [from] (low values) to [to] (high values). [domain] defaults to the
  /// data's minimum and maximum.
  const factory ColorScale.sequential(
    Color from,
    Color to, {
    ScaleDomain? domain,
  }) = SequentialScale;

  /// From [low] through [mid] (at [midpoint]) to [high]. [midpoint] defaults
  /// to the middle of the domain; [domain] to the data's range.
  const factory ColorScale.diverging(
    Color low,
    Color mid,
    Color high, {
    num? midpoint,
    ScaleDomain? domain,
  }) = DivergingScale;

  /// Steps: values below `breaks[0]` get `colors[0]`, values from
  /// `breaks[i - 1]` up to `breaks[i]` get `colors[i]`, and so on.
  /// [colors] has one more entry than [breaks].
  factory ColorScale.threshold(List<num> breaks, List<Color> colors) =
      ThresholdScale;

  /// One colour per category value (e.g. a string or enum). [labels] names
  /// the categories in the legend; otherwise `value.toString()` is used.
  const factory ColorScale.categorical(
    Map<Object, Color> colors, {
    Map<Object, LocalizedName>? labels,
  }) = CategoricalScale;

  /// The colour for [value], or `null` if the scale has none for it (wrong
  /// type, or an unknown category). [extent] is the data's range, used when
  /// the scale has no explicit domain.
  Color? colorOf(Object? value, ScaleDomain extent);

  /// The range of the numbers in [values], or `null` if there are none.
  static ScaleDomain? extentOf(Iterable<Object?> values) {
    num? min, max;
    for (final v in values) {
      if (v is! num || !v.isFinite) continue;
      if (min == null || v < min) min = v;
      if (max == null || v > max) max = v;
    }
    return min == null ? null : (min: min, max: max!);
  }
}

/// See [ColorScale.sequential].
final class SequentialScale extends ColorScale {
  /// Creates a sequential scale.
  const SequentialScale(this.from, this.to, {this.domain});

  /// Colour of the low end.
  final Color from;

  /// Colour of the high end.
  final Color to;

  /// Fixed range; `null` uses the data's range.
  final ScaleDomain? domain;

  @override
  Color? colorOf(Object? value, ScaleDomain extent) {
    if (value is! num || !value.isFinite) return null;
    final d = domain ?? extent;
    return lerpOklab(from, to, _fraction(value, d.min, d.max));
  }
}

/// See [ColorScale.diverging].
final class DivergingScale extends ColorScale {
  /// Creates a diverging scale.
  const DivergingScale(
    this.low,
    this.mid,
    this.high, {
    this.midpoint,
    this.domain,
  });

  /// Colour of the low end.
  final Color low;

  /// Colour at [midpoint].
  final Color mid;

  /// Colour of the high end.
  final Color high;

  /// Value that gets [mid]; `null` uses the middle of the domain.
  final num? midpoint;

  /// Fixed range; `null` uses the data's range.
  final ScaleDomain? domain;

  /// The value that gets [mid] for data spanning [extent].
  num midOf(ScaleDomain extent) {
    final d = domain ?? extent;
    return midpoint ?? (d.min + d.max) / 2;
  }

  @override
  Color? colorOf(Object? value, ScaleDomain extent) {
    if (value is! num || !value.isFinite) return null;
    final d = domain ?? extent;
    final m = midOf(extent);
    return value < m
        ? lerpOklab(low, mid, _fraction(value, d.min, m))
        : lerpOklab(mid, high, _fraction(value, m, d.max));
  }
}

/// See [ColorScale.threshold].
final class ThresholdScale extends ColorScale {
  /// Creates a threshold scale.
  ThresholdScale(this.breaks, this.colors)
    : assert(
        colors.length == breaks.length + 1,
        'colors needs one more entry than breaks',
      ),
      assert(
        [for (var i = 1; i < breaks.length; i++) breaks[i - 1] < breaks[i]]
            .every((ok) => ok),
        'breaks must be increasing',
      );

  /// Upper bounds (exclusive) of each step but the last.
  final List<num> breaks;

  /// One colour per step.
  final List<Color> colors;

  @override
  Color? colorOf(Object? value, ScaleDomain extent) {
    if (value is! num || !value.isFinite) return null;
    var i = 0;
    while (i < breaks.length && value >= breaks[i]) {
      i++;
    }
    return colors[i];
  }
}

/// See [ColorScale.categorical].
final class CategoricalScale extends ColorScale {
  /// Creates a categorical scale.
  const CategoricalScale(this.colors, {this.labels});

  /// Colour of each category.
  final Map<Object, Color> colors;

  /// Legend name of each category.
  final Map<Object, LocalizedName>? labels;

  @override
  Color? colorOf(Object? value, ScaleDomain extent) => colors[value];
}

double _fraction(num value, num min, num max) =>
    max == min ? 0.5 : ((value - min) / (max - min)).clamp(0.0, 1.0);

/// Interpolates between [a] and [b] in OKLab, a perceptually uniform colour
/// space: the midpoint looks halfway between the ends.
Color lerpOklab(Color a, Color b, double t) {
  // Exact at the ends, so the configured colours come back unchanged.
  if (t <= 0) return a;
  if (t >= 1) return b;
  final (l1, a1, b1) = _toOklab(a);
  final (l2, a2, b2) = _toOklab(b);
  double mix(double x, double y) => x + (y - x) * t;
  return _fromOklab(mix(l1, l2), mix(a1, a2), mix(b1, b2), mix(a.a, b.a));
}

double _toLinear(double c) =>
    c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _toSrgb(double c) =>
    (c <= 0.0031308 ? c * 12.92 : 1.055 * math.pow(c, 1 / 2.4) - 0.055)
        .clamp(0.0, 1.0)
        .toDouble();

double _cbrt(double x) =>
    x < 0 ? -math.pow(-x, 1 / 3).toDouble() : math.pow(x, 1 / 3).toDouble();

(double, double, double) _toOklab(Color c) {
  final r = _toLinear(c.r), g = _toLinear(c.g), b = _toLinear(c.b);
  final l = _cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
  final m = _cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
  final s = _cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
  return (
    0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
    1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
    0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
  );
}

Color _fromOklab(double lightness, double a, double b, double alpha) {
  final l = math
      .pow(lightness + 0.3963377774 * a + 0.2158037573 * b, 3)
      .toDouble();
  final m = math
      .pow(lightness - 0.1055613458 * a - 0.0638541728 * b, 3)
      .toDouble();
  final s = math
      .pow(lightness - 0.0894841775 * a - 1.2914855480 * b, 3)
      .toDouble();
  return Color.from(
    alpha: alpha,
    red: _toSrgb(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s),
    green: _toSrgb(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s),
    blue: _toSrgb(-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s),
  );
}
