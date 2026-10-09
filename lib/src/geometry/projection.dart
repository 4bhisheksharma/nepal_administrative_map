import 'dart:math' as math;
import 'dart:typed_data';

import 'lat_lng.dart';

/// Spherical Web Mercator, normalised so the world is the unit square.
///
/// x grows east and y grows south (like screen coordinates), both in 0…1.
/// The same projection as standard web maps, so markers and any tile
/// overlays line up.
abstract final class WebMercator {
  static const _maxLatitude = 85.0511287798066;

  /// Projects [point] to unit-square coordinates.
  static ({double x, double y}) project(LatLng point) =>
      (x: _x(point.longitude), y: _y(point.latitude));

  /// Inverse of [project].
  static LatLng unproject(double x, double y) {
    final lat = math.atan(_sinh(math.pi * (1 - 2 * y))) * 180 / math.pi;
    return LatLng(lat.clamp(-90.0, 90.0), (x * 360 - 180).clamp(-180.0, 180.0));
  }

  /// Projects interleaved `[lng, lat, …]` coordinates to `[x, y, …]`.
  static Float64List projectCoords(Float64List lngLat) {
    final out = Float64List(lngLat.length);
    for (var i = 0; i < lngLat.length; i += 2) {
      out[i] = _x(lngLat[i]);
      out[i + 1] = _y(lngLat[i + 1]);
    }
    return out;
  }

  static double _x(double lng) => (lng + 180) / 360;

  static double _y(double lat) {
    final phi = lat.clamp(-_maxLatitude, _maxLatitude) * math.pi / 180;
    return (1 - math.log(math.tan(math.pi / 4 + phi / 2)) / math.pi) / 2;
  }

  static double _sinh(double v) => (math.exp(v) - math.exp(-v)) / 2;
}
