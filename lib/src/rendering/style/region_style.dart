import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../data/models/region.dart';

/// How one region is drawn.
@immutable
class RegionStyle {
  /// Creates a style.
  const RegionStyle({required this.fill, this.outline, this.outlineWidth = 2});

  /// Fill colour.
  final Color fill;

  /// If set, the region's outline is drawn on top of every border in this
  /// colour (used for selection). Borders between regions come from
  /// [NepalMapTheme], so each shared border is drawn once.
  final Color? outline;

  /// Width of [outline] in logical pixels.
  final double outlineWidth;

  /// A copy with the given fields replaced.
  RegionStyle copyWith({Color? fill, Color? outline, double? outlineWidth}) =>
      RegionStyle(
        fill: fill ?? this.fill,
        outline: outline ?? this.outline,
        outlineWidth: outlineWidth ?? this.outlineWidth,
      );

  @override
  bool operator ==(Object other) =>
      other is RegionStyle &&
      other.fill == fill &&
      other.outline == outline &&
      other.outlineWidth == outlineWidth;

  @override
  int get hashCode => Object.hash(fill, outline, outlineWidth);
}

/// What is happening to a region, passed to a [RegionStyleBuilder].
@immutable
class RegionState {
  /// Creates a state.
  const RegionState({
    this.isSelected = false,
    this.isHovered = false,
    this.isHighlighted = false,
    this.isFocused = false,
    this.value,
  });

  /// Whether the region is selected.
  final bool isSelected;

  /// Whether the mouse is over the region (desktop and web).
  final bool isHovered;

  /// Whether the region was highlighted with `NepalMapController.highlight`.
  final bool isHighlighted;

  /// Whether the region has keyboard focus (shown only while the keyboard is
  /// in use).
  final bool isFocused;

  /// The region's value on a choropleth map, or `null` without one.
  final Object? value;

  @override
  bool operator ==(Object other) =>
      other is RegionState &&
      other.isSelected == isSelected &&
      other.isHovered == isHovered &&
      other.isHighlighted == isHighlighted &&
      other.isFocused == isFocused &&
      other.value == value;

  @override
  int get hashCode =>
      Object.hash(isSelected, isHovered, isHighlighted, isFocused, value);
}

/// Decides how each region is drawn.
///
/// ```dart
/// style: (region, state) => RegionStyle(
///   fill: state.isSelected ? Colors.orange : Colors.green.shade100,
/// ),
/// ```
typedef RegionStyleBuilder = RegionStyle Function(
  Region region,
  RegionState state,
);
