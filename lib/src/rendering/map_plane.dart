import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../geometry/bounds.dart';
import '../geometry/lat_lng.dart';
import '../geometry/projection.dart';

/// Web Mercator, shifted and scaled so Nepal spans [width] units.
///
/// Paths are built once in this plane. Keeping coordinates in the hundreds
/// (instead of Web Mercator's 0–1 world) keeps the zoom scale factors and
/// stroke widths in a range every renderer handles well.
class MapPlane {
  /// Creates a plane fitted to [bounds] (in degrees).
  factory MapPlane(Bounds bounds) {
    final topLeft = WebMercator.project(LatLng(bounds.maxY, bounds.minX));
    final bottomRight = WebMercator.project(LatLng(bounds.minY, bounds.maxX));
    final k = width / (bottomRight.x - topLeft.x);
    return MapPlane._(topLeft.x, topLeft.y, k, (bottomRight.y - topLeft.y) * k);
  }

  MapPlane._(this._x0, this._y0, this._k, this.height);

  /// Nepal's width in plane units.
  static const double width = 1000;

  /// Nepal's height in plane units.
  final double height;

  final double _x0, _y0, _k;

  /// The rectangle Nepal occupies.
  Rect get rect => Rect.fromLTWH(0, 0, width, height);

  /// Plane position of [point].
  Offset project(LatLng point) {
    final p = WebMercator.project(point);
    return Offset((p.x - _x0) * _k, (p.y - _y0) * _k);
  }

  /// Geographic position of a plane point.
  LatLng unproject(Offset p) =>
      WebMercator.unproject(p.dx / _k + _x0, p.dy / _k + _y0);

  /// Projects interleaved `[lng, lat, …]` to plane `[x, y, …]`.
  Float64List projectCoords(Float64List lngLat) {
    final out = WebMercator.projectCoords(lngLat);
    for (var i = 0; i < out.length; i += 2) {
      out[i] = (out[i] - _x0) * _k;
      out[i + 1] = (out[i + 1] - _y0) * _k;
    }
    return out;
  }

  /// Plane rectangle covering geographic [bounds].
  Rect rectOf(Bounds bounds) => Rect.fromPoints(
    project(LatLng(bounds.maxY, bounds.minX)),
    project(LatLng(bounds.minY, bounds.maxX)),
  );
}

/// Maps plane coordinates to widget pixels: `pixel = plane * scale + offset`.
@immutable
class ViewTransform {
  /// Creates a transform.
  const ViewTransform(this.scale, this.offset);

  /// Fits [content] (a plane rectangle) inside [size] minus [padding],
  /// centred.
  factory ViewTransform.fit(Rect content, Size size, EdgeInsets padding) {
    final available = padding.deflateSize(size);
    if (content.isEmpty || available.isEmpty) {
      return const ViewTransform(1, Offset.zero);
    }
    final scale = (available.width / content.width).clamp(
      0.0,
      available.height / content.height,
    );
    final offset =
        Offset(
          padding.left + (available.width - content.width * scale) / 2,
          padding.top + (available.height - content.height * scale) / 2,
        ) -
        content.topLeft * scale;
    return ViewTransform(scale, offset);
  }

  /// Pixels per plane unit.
  final double scale;

  /// Pixel position of the plane origin.
  final Offset offset;

  /// Plane point → pixel.
  Offset toScreen(Offset plane) => plane * scale + offset;

  /// Pixel → plane point.
  Offset toPlane(Offset screen) => (screen - offset) / scale;

  /// Applies this transform to [canvas].
  void apply(Canvas canvas) {
    canvas
      ..translate(offset.dx, offset.dy)
      ..scale(scale);
  }

  @override
  bool operator ==(Object other) =>
      other is ViewTransform && other.scale == scale && other.offset == offset;

  @override
  int get hashCode => Object.hash(scale, offset);
}
