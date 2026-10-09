import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../data/models/region.dart';
import '../geometry_cache.dart';
import '../map_layer.dart';

/// Region names, drawn at a constant size in screen space.
///
/// Each label sits at its region's pole of inaccessibility and is shown only
/// if it fits inside the region at the current zoom and doesn't overlap a
/// label already placed. Larger regions are placed first.
class LabelLayer extends MapLayer {
  /// Creates the layer. [cache] holds the laid-out text between frames.
  const LabelLayer(this.cache);

  /// Laid-out text, reused until the text or style changes.
  final LabelCache cache;

  /// How far (as a multiple of the inscribed circle's radius) a label may
  /// extend from its anchor. Slightly over 1 lets labels use the space of
  /// elongated regions.
  static const _fitWidth = 1.35;
  static const _fitHeight = 0.95;

  /// Minimum gap between labels, in logical pixels.
  static const _gap = 2.0;

  @override
  bool get screenSpace => true;

  @override
  void paint(Canvas canvas, MapPaintContext context) {
    for (final placed in place(context, canvas.getLocalClipBounds())) {
      placed.label.paint(canvas, placed.rect.topLeft);
    }
  }

  /// Chooses which labels to show and where, in screen pixels.
  ///
  /// Region and protected-area labels are tried largest area first; each is
  /// kept only if its anchor is inside [bounds], it fits inside its shape at
  /// the current zoom, and it doesn't overlap a label already kept.
  List<({Object feature, Rect rect, MapLabel label})> place(
    MapPaintContext context,
    Rect bounds,
  ) {
    final placed = <({Object feature, Rect rect, MapLabel label})>[];
    final candidates = cache.candidates(context);
    cache.prepare(
      context.labelStyle,
      context.theme.labelColor,
      context.theme.labelHaloColor,
    );
    final transform = context.transform;
    for (final (feature, text, anchor) in candidates) {
      final radius = anchor.radius * transform.scale;
      if (radius < 4) continue; // too small to hold any label
      final center = transform.toScreen(anchor.point);
      if (!bounds.contains(center)) continue;

      final label = cache.layout(feature, text);
      final size = label.size;
      if (size.width / 2 > radius * _fitWidth ||
          size.height / 2 > radius * _fitHeight) {
        continue;
      }
      final rect = Rect.fromCenter(
        center: center,
        width: size.width,
        height: size.height,
      );
      if (placed.any((p) => p.rect.overlaps(rect.inflate(_gap)))) continue;
      placed.add((feature: feature, rect: rect, label: label));
    }
    return placed;
  }

  @override
  bool needsRepaint(MapPaintContext old, MapPaintContext current) =>
      old.view != current.view ||
      old.labelStyle != current.labelStyle ||
      old.theme.labelColor != current.theme.labelColor ||
      old.theme.labelHaloColor != current.theme.labelHaloColor ||
      !mapEquals(old.labels, current.labels) ||
      !mapEquals(old.protectedAreaLabels, current.protectedAreaLabels);

  @override
  bool operator ==(Object other) =>
      other is LabelLayer && identical(other.cache, cache);

  @override
  int get hashCode => identityHashCode(cache);
}

/// One laid-out label: a halo pass and a fill pass.
class MapLabel {
  /// Lays out [text] in [style], filled with [color] over a [halo].
  MapLabel(this.text, this.style, this.color, this.halo)
    : _halo = _painter(
        text,
        style.copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..strokeJoin = StrokeJoin.round
            ..color = halo,
        ),
      ),
      _fill = _painter(text, style.copyWith(color: color));

  /// The label text.
  final String text;

  /// Font, size and weight.
  final TextStyle style;

  /// Text colour.
  final Color color;

  /// Halo colour.
  final Color halo;

  final TextPainter _halo;
  final TextPainter _fill;

  /// Laid-out size.
  Size get size => _fill.size;

  /// Paints the label with its top-left corner at [topLeft].
  void paint(Canvas canvas, Offset topLeft) {
    _halo.paint(canvas, topLeft);
    _fill.paint(canvas, topLeft);
  }

  /// Releases the text painters.
  void dispose() {
    _halo.dispose();
    _fill.dispose();
  }

  static TextPainter _painter(String text, TextStyle style) => TextPainter(
    text: TextSpan(text: text, style: style),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
  )..layout();
}

/// Laid-out labels and placement order, reused between frames.
///
/// Text is measured once per region and reused until its text or the label
/// style changes (e.g. on a language switch). The candidate list, sorted
/// largest shape first, is rebuilt only when the label texts change.
class LabelCache {
  final _labels = <Object, MapLabel>{};
  TextStyle? _style;
  Color? _color;
  Color? _halo;
  Map<Region, String>? _labelsFor;
  Map<ProtectedArea, String>? _areaLabelsFor;
  List<(Object, String, LabelAnchor)> _candidates = const [];

  /// Number of labels laid out since creation. For tests.
  @visibleForTesting
  int layoutCount = 0;

  /// Region and protected-area labels with their anchors, largest first.
  List<(Object, String, LabelAnchor)> candidates(MapPaintContext context) {
    if (identical(context.labels, _labelsFor) &&
        identical(context.protectedAreaLabels, _areaLabelsFor)) {
      return _candidates;
    }
    _labelsFor = context.labels;
    _areaLabelsFor = context.protectedAreaLabels;
    final geometry = context.cache;
    return _candidates = [
      for (final MapEntry(key: region, value: text) in context.labels.entries)
        (region, text, geometry.labelAnchor(region)),
      for (final MapEntry(key: area, value: text)
          in context.protectedAreaLabels.entries)
        (area, text, geometry.protectedAreaAnchor(area)),
    ]..sort((a, b) => b.$3.area.compareTo(a.$3.area));
  }

  /// Sets the style for this frame; laid-out labels are dropped if it
  /// changed.
  void prepare(TextStyle style, Color color, Color halo) {
    if (identical(style, _style) ||
        (style == _style && color == _color && halo == _halo)) {
      _style = style;
      return;
    }
    dispose();
    _style = style;
    _color = color;
    _halo = halo;
  }

  /// The laid-out label for [feature], reusing the cached one if its text
  /// is unchanged. Call [prepare] first.
  MapLabel layout(Object feature, String text) {
    final cached = _labels[feature];
    if (cached != null && cached.text == text) return cached;
    cached?.dispose();
    layoutCount++;
    return _labels[feature] = MapLabel(text, _style!, _color!, _halo!);
  }

  /// Releases every laid-out label.
  void dispose() {
    for (final label in _labels.values) {
      label.dispose();
    }
    _labels.clear();
  }
}
