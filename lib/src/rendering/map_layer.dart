import 'dart:ui' show Picture, PictureRecorder;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../data/models/region.dart';
import '../geometry/lat_lng.dart';
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
    this.labels = const {},
    this.protectedAreaLabels = const {},
    this.labelStyle = const TextStyle(),
  });

  /// Shared plane-space paths and label anchors.
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

  /// The label text of each labelled region.
  final Map<Region, String> labels;

  /// The label text of each protected area shown by the overlay.
  final Map<ProtectedArea, String> protectedAreaLabels;

  /// Resolved label text style (font, size, weight; colours from [theme]).
  final TextStyle labelStyle;

  /// Converts a width in logical pixels to plane units, so lines keep the
  /// same on-screen width at any zoom.
  double pixels(double logicalPixels) => logicalPixels / transform.scale;

  /// Plane position of [point], for plane-space layers.
  Offset project(LatLng point) => cache.plane.project(point);

  /// Screen position of [point], for screen-space layers.
  Offset toScreen(LatLng point) => transform.toScreen(project(point));

  /// Whether the zoom differs from [other]'s by more than [tolerance]
  /// (15% by default). Layers whose line widths depend on the scale use this
  /// to re-record only occasionally while zooming; a line drawn up to 15%
  /// too thin or thick for a moment is invisible.
  bool scaleDiffers(MapPaintContext other, {double tolerance = 0.15}) {
    final ratio = transform.scale / other.transform.scale;
    return ratio > 1 + tolerance || ratio < 1 / (1 + tolerance);
  }
}

/// One drawing pass of the map, e.g. fills or borders.
///
/// Add your own with `NepalMap.extraLayers`:
///
/// ```dart
/// class CityDots extends MapLayer {
///   const CityDots(this.cities);
///   final List<LatLng> cities;
///
///   @override
///   void paint(Canvas canvas, MapPaintContext context) {
///     final paint = Paint()..color = Colors.red;
///     for (final city in cities) {
///       canvas.drawCircle(context.project(city), context.pixels(4), paint);
///     }
///   }
///
///   // The radius is in pixels, so it changes with the zoom.
///   @override
///   bool needsRepaint(MapPaintContext old, MapPaintContext current) =>
///       old.transform.scale != current.transform.scale;
///
///   @override
///   bool operator ==(Object other) =>
///       other is CityDots && listEquals(other.cities, cities);
///
///   @override
///   int get hashCode => Object.hashAll(cities);
/// }
/// ```
///
/// Layers are compared with `==` to decide whether to repaint, so give a
/// layer with settings value equality.
abstract class MapLayer {
  /// Const constructor for subclasses.
  const MapLayer();

  /// Whether [paint] draws in screen pixels (e.g. text) instead of plane
  /// units. Plane-space layers are recorded once and replayed under the
  /// camera transform, so panning doesn't redraw them.
  bool get screenSpace => false;

  /// Paints the layer. For plane-space layers the canvas is in plane units
  /// (use [MapPaintContext.project] and [MapPaintContext.pixels]); for
  /// screen-space layers it's in pixels (use [MapPaintContext.toScreen]).
  void paint(Canvas canvas, MapPaintContext context);

  /// Whether going from [old] to [current] changes what this layer draws.
  ///
  /// For plane-space layers, ignore the transform's offset (panning) and
  /// compare its scale only if sizes depend on it. Screen-space layers are
  /// repainted on every transform change regardless.
  bool needsRepaint(MapPaintContext old, MapPaintContext current);
}

/// A plane-space layer's recorded drawing, reused while it's still valid.
class LayerRecording {
  MapLayer? _layer;
  MapPaintContext? _context;
  Picture? _picture;

  /// Releases the recorded picture.
  void dispose() {
    _picture?.dispose();
    _picture = null;
    _context = null;
    _layer = null;
  }
}

/// Adapts a [MapLayer] to a [CustomPainter].
class MapLayerPainter extends CustomPainter {
  /// Creates a painter for [layer]; plane-space layers reuse [recording].
  MapLayerPainter(this.layer, this.context, this.recording);

  /// The layer to paint.
  final MapLayer layer;

  /// The frame's context.
  final MapPaintContext context;

  /// Cache for the layer's recorded drawing.
  final LayerRecording recording;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..clipRect(Offset.zero & size);
    if (layer.screenSpace) {
      layer.paint(canvas, context);
    } else {
      final recorded = recording._context;
      if (recording._picture == null ||
          recorded == null ||
          recording._layer != layer ||
          layer.needsRepaint(recorded, context)) {
        final recorder = PictureRecorder();
        layer.paint(Canvas(recorder), context);
        recording
          ..dispose()
          .._picture = recorder.endRecording()
          .._context = context
          .._layer = layer;
      }
      context.transform.apply(canvas);
      canvas.drawPicture(recording._picture!);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(MapLayerPainter oldDelegate) =>
      oldDelegate.layer != layer ||
      oldDelegate.context.transform != context.transform ||
      layer.needsRepaint(oldDelegate.context, context);
}
