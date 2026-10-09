import 'dart:ui';

import '../map_layer.dart';

/// Draws every shared border once: inner borders, coarser-level borders on
/// top of them, then the outer edge.
class BorderLayer extends MapLayer {
  /// Creates the layer.
  const BorderLayer();

  @override
  void paint(Canvas canvas, MapPaintContext context) {
    final borders = context.cache.borders(context.view);
    final theme = context.theme;
    Paint stroke(Color color, double width) => Paint()
      ..style = PaintingStyle.stroke
      ..color = color
      ..strokeWidth = context.pixels(width)
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    canvas
      ..drawPath(borders.inner, stroke(theme.borderColor, theme.borderWidth))
      ..drawPath(
        borders.parent,
        stroke(theme.parentBorderColor, theme.parentBorderWidth),
      )
      ..drawPath(
        borders.outline,
        stroke(theme.outlineColor, theme.outlineWidth),
      );
  }

  @override
  bool shouldRepaint(MapPaintContext old, MapPaintContext current) =>
      old.view != current.view ||
      old.transform != current.transform ||
      old.theme != current.theme;
}
