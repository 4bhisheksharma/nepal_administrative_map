import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nepal_administrative_map/nepal_administrative_map.dart';

/// A custom [MapLayer]: a soft glow around each point, drawn in plane units
/// so it grows when you zoom in.
class CityGlowLayer extends MapLayer {
  const CityGlowLayer(this.points, this.color);

  final List<LatLng> points;
  final Color color;

  @override
  void paint(Canvas canvas, MapPaintContext context) {
    // 12 plane units ≈ 1/80 of Nepal's width.
    const radius = 12.0;
    for (final point in points) {
      final center = context.project(point);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [color.withValues(alpha: 0.45), color.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }
  }

  // Sizes are in plane units, so panning and zooming never need a redraw.
  @override
  bool needsRepaint(MapPaintContext old, MapPaintContext current) => false;

  @override
  bool operator ==(Object other) =>
      other is CityGlowLayer &&
      other.color == color &&
      listEquals(other.points, points);

  @override
  int get hashCode => Object.hash(color, Object.hashAll(points));
}
