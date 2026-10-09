import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../map_layer.dart';

/// Fills each shown region with its style's fill colour.
///
/// On local-level maps it first fills the protected areas, which belong to
/// no local level, clipped to the scope region.
class RegionFillLayer extends MapLayer {
  /// Creates the layer.
  const RegionFillLayer();

  @override
  void paint(Canvas canvas, MapPaintContext context) {
    final paint = Paint()..isAntiAlias = true;
    final protectedAreas = context.cache.protectedAreas(context.view);
    if (protectedAreas.isNotEmpty) {
      canvas.save();
      if (context.view.scope case final scope?) {
        canvas.clipPath(context.cache.pathOf(scope));
      }
      paint.color = context.theme.protectedAreaFill;
      for (final area in protectedAreas) {
        canvas.drawPath(context.cache.protectedAreaPath(area), paint);
      }
      canvas.restore();
    }
    for (final region in context.cache.regions(context.view)) {
      paint.color = context.styles[region]!.fill;
      canvas.drawPath(context.cache.pathOf(region), paint);
    }
  }

  @override
  bool needsRepaint(MapPaintContext old, MapPaintContext current) =>
      old.view != current.view ||
      old.theme.protectedAreaFill != current.theme.protectedAreaFill ||
      !mapEquals(old.styles, current.styles);
}
