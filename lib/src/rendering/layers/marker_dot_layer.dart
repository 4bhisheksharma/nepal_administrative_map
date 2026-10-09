import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../widget/map_marker.dart';
import '../map_layer.dart';

/// Paints dot markers in screen space, so they keep their size when
/// zooming.
class MarkerDotLayer extends MapLayer {
  /// Creates the layer for the dot markers among [markers].
  MarkerDotLayer(List<MapMarker> markers, this.defaultColor)
    : dots = [
        for (final m in markers)
          if (m.isDot) m,
      ];

  /// The dots to paint.
  final List<MapMarker> dots;

  /// Colour of dots without their own.
  final Color defaultColor;

  @override
  bool get screenSpace => true;

  @override
  void paint(Canvas canvas, MapPaintContext context) {
    final bounds = canvas.getLocalClipBounds();
    final fill = Paint();
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = context.theme.labelHaloColor;
    for (final dot in dots) {
      final p = context.toScreen(dot.point);
      if (!bounds.inflate(dot.radius).contains(p)) continue;
      fill.color = dot.color ?? defaultColor;
      canvas
        ..drawCircle(p, dot.radius, fill)
        ..drawCircle(p, dot.radius, ring);
    }
  }

  @override
  bool needsRepaint(MapPaintContext old, MapPaintContext current) =>
      old.theme.labelHaloColor != current.theme.labelHaloColor;

  @override
  bool operator ==(Object other) =>
      other is MarkerDotLayer &&
      other.defaultColor == defaultColor &&
      listEquals(other.dots, dots);

  @override
  int get hashCode => Object.hash(defaultColor, Object.hashAll(dots));
}
