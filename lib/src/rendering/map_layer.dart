import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../data/models/region.dart';
import '../i18n/map_language.dart';
import 'geometry_cache.dart';
import 'map_plane.dart';
import 'style/nepal_map_theme.dart';
import 'style/region_style.dart';

/// Everything a layer needs to paint one frame.
@immutable
class MapPaintContext {
  /// Creates a context.
  const MapPaintContext({
    required this.cache,
    required this.view,
    required this.transform,
    required this.theme,
    required this.language,
    required this.styles,
  });

  /// Shared plane-space paths.
  final GeometryCache cache;

  /// The shown level and scope.
  final MapView view;

  /// Plane → pixels.
  final ViewTransform transform;

  /// Colours and widths.
  final NepalMapTheme theme;

  /// The active language.
  final MapLanguage language;

  /// The resolved style of every shown region.
  final Map<Region, RegionStyle> styles;

  /// Converts a width in logical pixels to plane units, so lines keep the
  /// same on-screen width at any zoom.
  double pixels(double logicalPixels) => logicalPixels / transform.scale;
}

/// One drawing pass of the map, e.g. fills or borders.
abstract class MapLayer {
  /// Const constructor for subclasses.
  const MapLayer();

  /// Paints in plane coordinates; the canvas is already transformed.
  void paint(Canvas canvas, MapPaintContext context);

  /// Whether going from [old] to [current] changes this layer's output.
  bool shouldRepaint(MapPaintContext old, MapPaintContext current);
}

/// Adapts a [MapLayer] to a [CustomPainter].
class MapLayerPainter extends CustomPainter {
  /// Creates a painter for [layer] with [context].
  MapLayerPainter(this.layer, this.context);

  /// The layer to paint.
  final MapLayer layer;

  /// The frame's context.
  final MapPaintContext context;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..clipRect(Offset.zero & size);
    context.transform.apply(canvas);
    layer.paint(canvas, context);
    canvas.restore();
  }

  @override
  bool shouldRepaint(MapLayerPainter oldDelegate) =>
      oldDelegate.layer.runtimeType != layer.runtimeType ||
      layer.shouldRepaint(oldDelegate.context, context);
}
