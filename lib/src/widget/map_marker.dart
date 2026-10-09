import 'package:flutter/widgets.dart';

import '../geometry/lat_lng.dart';

/// Something to show at a geographic point on the map.
///
/// Widget markers ([MapMarker.new]) are best for a few dozen points; dot
/// markers ([MapMarker.dot]) are painted and stay fast with thousands.
@immutable
class MapMarker {
  /// A widget at [point]. [alignment] says which part of the widget sits on
  /// the point: the default, bottom centre, suits pins.
  const MapMarker({
    required this.point,
    required Widget this.child,
    this.size = const Size(32, 32),
    this.alignment = Alignment.bottomCenter,
    this.data,
  }) : color = null,
       radius = 0;

  /// A painted dot at [point], [radius] logical pixels across the middle.
  /// [color] defaults to the theme's primary colour.
  const MapMarker.dot({
    required this.point,
    this.color,
    this.radius = 4,
    this.data,
  }) : child = null,
       size = Size.zero,
       alignment = Alignment.center;

  /// Where the marker goes.
  final LatLng point;

  /// The widget, for widget markers.
  final Widget? child;

  /// Size of [child].
  final Size size;

  /// Which point of [child] sits on [point].
  final Alignment alignment;

  /// Dot colour, for dot markers.
  final Color? color;

  /// Dot radius in logical pixels, for dot markers.
  final double radius;

  /// Anything you want back in `onMarkerTap`, e.g. an id.
  final Object? data;

  /// Whether this is a painted dot rather than a widget.
  bool get isDot => child == null;

  @override
  bool operator ==(Object other) =>
      other is MapMarker &&
      other.point == point &&
      other.child == child &&
      other.size == size &&
      other.alignment == alignment &&
      other.color == color &&
      other.radius == radius &&
      other.data == data;

  @override
  int get hashCode =>
      Object.hash(point, child, size, alignment, color, radius, data);
}
