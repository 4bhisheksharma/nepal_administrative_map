import 'dart:ui';

import '../map_layer.dart';

/// The opt-in protected-area overlay: a tint, diagonal hatching and an
/// outline over each protected area in view, clipped to the scope.
class ProtectedAreaLayer extends MapLayer {
  /// Creates the layer.
  const ProtectedAreaLayer();

  /// Hatch spacing in logical pixels.
  static const _spacing = 6.0;

  @override
  void paint(Canvas canvas, MapPaintContext context) {
    final cache = context.cache;
    final areas = cache.protectedAreasIn(context.view.scope);
    if (areas.isEmpty) return;
    final color = context.theme.protectedAreaOverlay;
    final tint = Paint()..color = color.withValues(alpha: color.a * 0.18);
    final hatch = Paint()
      ..color = color.withValues(alpha: color.a * 0.5)
      ..strokeWidth = context.pixels(0.8);
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..color = color
      ..strokeWidth = context.pixels(1);
    final spacing = context.pixels(_spacing);

    canvas.save();
    if (context.view.scope case final scope?) {
      canvas.clipPath(cache.pathOf(scope));
    }
    for (final area in areas) {
      final path = cache.protectedAreaPath(area);
      final b = path.getBounds();
      canvas
        ..drawPath(path, tint)
        ..save()
        ..clipPath(path);
      // 45° lines covering the bounding box.
      for (var x = b.left - b.height; x < b.right; x += spacing) {
        canvas.drawLine(
          Offset(x, b.bottom),
          Offset(x + b.height, b.top),
          hatch,
        );
      }
      canvas
        ..restore()
        ..drawPath(path, outline);
    }
    canvas.restore();
  }

  @override
  bool needsRepaint(MapPaintContext old, MapPaintContext current) =>
      old.view != current.view ||
      old.transform.scale != current.transform.scale ||
      old.theme.protectedAreaOverlay != current.theme.protectedAreaOverlay;
}
