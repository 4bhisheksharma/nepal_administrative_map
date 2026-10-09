import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'map_plane.dart';

/// What part of the plane the map shows.
///
/// [zoom] is relative to the view's fitted size: 1 shows the whole view
/// (the country, or the scope region), 2 shows it twice as large. Keeping it
/// relative means resizing the widget keeps the user's zoom.
@immutable
class MapCamera {
  /// Creates a camera looking at [center] (a plane point).
  const MapCamera({required this.center, this.zoom = 1});

  /// The camera that fits [content] exactly.
  factory MapCamera.fit(Rect content) => MapCamera(center: content.center);

  /// Plane point shown at the middle of the padded viewport.
  final Offset center;

  /// Magnification relative to the fitted view.
  final double zoom;

  /// Pixels per plane unit that fit [content] into [size] minus [padding].
  static double fitScale(Rect content, Size size, EdgeInsets padding) =>
      ViewTransform.fit(content, size, padding).scale;

  /// The plane → pixel transform for this camera.
  ViewTransform transform(Rect content, Size size, EdgeInsets padding) {
    final scale = fitScale(content, size, padding) * zoom;
    final viewport = padding.deflateRect(Offset.zero & size).center;
    return ViewTransform(scale, viewport - center * scale);
  }

  /// This camera with [zoom] in [minZoom]…[maxZoom] and [center] inside
  /// [content], so the map can never be dragged fully off screen.
  MapCamera clamp(Rect content, double minZoom, double maxZoom) => MapCamera(
    center: Offset(
      center.dx.clamp(content.left, content.right),
      center.dy.clamp(content.top, content.bottom),
    ),
    zoom: zoom.clamp(minZoom, maxZoom),
  );

  /// The camera that keeps [planePoint] under [screenPoint] at [zoom].
  static MapCamera anchored({
    required Offset planePoint,
    required Offset screenPoint,
    required double zoom,
    required Rect content,
    required Size size,
    required EdgeInsets padding,
  }) {
    final scale = fitScale(content, size, padding) * zoom;
    final viewport = padding.deflateRect(Offset.zero & size).center;
    return MapCamera(
      center: planePoint - (screenPoint - viewport) / scale,
      zoom: zoom,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MapCamera && other.center == center && other.zoom == zoom;

  @override
  int get hashCode => Object.hash(center, zoom);

  @override
  String toString() => 'MapCamera($center, zoom: $zoom)';
}

/// An absolute camera position (pixels per plane unit), used to animate
/// between views whose fitted scales differ, e.g. when drilling down.
@immutable
class CameraFlight {
  /// Flies from [from] to [to], both in absolute scale.
  const CameraFlight(this.from, this.to);

  /// Start: centre and absolute scale.
  final (Offset center, double scale) from;

  /// End: centre and absolute scale.
  final (Offset center, double scale) to;

  /// Position at [t] (0…1). Scale moves on a log curve so zooming feels
  /// even; the centre moves linearly.
  (Offset center, double scale) at(double t) => (
    Offset.lerp(from.$1, to.$1, t)!,
    math.exp(lerpDouble(math.log(from.$2), math.log(to.$2), t)!),
  );
}
