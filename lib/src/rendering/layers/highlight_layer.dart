import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../map_layer.dart';

/// Outlines regions whose style has an outline (e.g. the selection), above
/// every border.
class HighlightLayer extends MapLayer {
  /// Creates the layer.
  const HighlightLayer();

  @override
  void paint(Canvas canvas, MapPaintContext context) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    for (final MapEntry(key: region, value: style) in context.styles.entries) {
      final color = style.outline;
      if (color == null) continue;
      paint
        ..color = color
        ..strokeWidth = context.pixels(style.outlineWidth);
      canvas.drawPath(context.cache.pathOf(region), paint);
    }
  }

  @override
  bool needsRepaint(MapPaintContext old, MapPaintContext current) =>
      old.view != current.view ||
      old.transform.scale != current.transform.scale ||
      !mapEquals(old.styles, current.styles);
}
