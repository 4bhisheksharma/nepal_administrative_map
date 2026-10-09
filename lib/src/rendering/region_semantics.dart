import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../data/models/region.dart';
import 'geometry_cache.dart';
import 'map_plane.dart';

/// Paints nothing; describes each visible region to screen readers.
///
/// Each region on screen gets a node with its name (and value, on a
/// choropleth) in the active language, its selection state, and a tap
/// action. Regions smaller than a few pixels are left out until zoomed in.
class RegionSemanticsPainter extends CustomPainter {
  /// Creates the painter.
  RegionSemanticsPainter({
    required this.cache,
    required this.view,
    required this.transform,
    required this.labels,
    required this.selection,
    required this.onActivate,
  });

  /// Plane bounds of the regions.
  final GeometryCache cache;

  /// The shown regions.
  final MapView view;

  /// Plane → pixels.
  final ViewTransform transform;

  /// What a screen reader says for each region.
  final Map<Region, String> labels;

  /// Selected regions.
  final Set<Region> selection;

  /// Called for the screen reader's "activate" action.
  final ValueChanged<Region> onActivate;

  static const _minSize = 6.0;

  @override
  void paint(Canvas canvas, Size size) {}

  // Never takes pointer events from the map or markers above it.
  @override
  bool? hitTest(Offset position) => false;

  @override
  SemanticsBuilderCallback get semanticsBuilder => (size) {
    final viewport = Offset.zero & size;
    return [
      for (final region in cache.regions(view))
        if (_screenRect(region, viewport) case final rect?)
          CustomPainterSemantics(
            key: ValueKey(region.code),
            rect: rect,
            properties: SemanticsProperties(
              label: labels[region],
              selected: selection.contains(region),
              button: true,
              textDirection: TextDirection.ltr,
              onTap: () => onActivate(region),
            ),
          ),
    ];
  };

  Rect? _screenRect(Region region, Rect viewport) {
    final b = cache.planeBounds(region);
    final rect = Rect.fromPoints(
      transform.toScreen(b.topLeft),
      transform.toScreen(b.bottomRight),
    );
    if (!rect.overlaps(viewport) ||
        (rect.width < _minSize && rect.height < _minSize)) {
      return null;
    }
    return rect.intersect(viewport);
  }

  @override
  bool shouldRepaint(RegionSemanticsPainter oldDelegate) => false;

  @override
  bool shouldRebuildSemantics(RegionSemanticsPainter oldDelegate) =>
      oldDelegate.view != view ||
      oldDelegate.transform != transform ||
      !setEquals(oldDelegate.selection, selection) ||
      !mapEquals(oldDelegate.labels, labels);
}
