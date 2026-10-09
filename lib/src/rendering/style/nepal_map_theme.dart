import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../data/models/region.dart';
import 'region_style.dart';

/// Colours and line widths of a [NepalMap].
///
/// Set it app-wide through `ThemeData.extensions`, or per map through
/// `NepalMap.theme`. Without either, colours come from the app's
/// [ColorScheme], so light and dark mode work automatically.
///
/// ```dart
/// ThemeData(extensions: [NepalMapTheme.fromColorScheme(scheme).copyWith(
///   regionFill: Colors.teal.shade50,
/// )]);
/// ```
@immutable
class NepalMapTheme extends ThemeExtension<NepalMapTheme> {
  /// Creates a theme.
  const NepalMapTheme({
    required this.regionFill,
    required this.selectedFill,
    required this.selectedOutline,
    required this.borderColor,
    required this.parentBorderColor,
    required this.outlineColor,
    required this.protectedAreaFill,
    this.borderWidth = 0.5,
    this.parentBorderWidth = 1.2,
    this.outlineWidth = 1.2,
    this.attributionStyle,
  });

  /// Default theme for [scheme].
  factory NepalMapTheme.fromColorScheme(ColorScheme scheme) => NepalMapTheme(
    regionFill: scheme.surfaceContainerHighest,
    selectedFill: scheme.primaryContainer,
    selectedOutline: scheme.primary,
    borderColor: scheme.surface,
    parentBorderColor: scheme.outline,
    outlineColor: scheme.outline,
    protectedAreaFill: scheme.surfaceContainerLow,
  );

  /// The theme a map in [context] uses when `NepalMap.theme` isn't set.
  static NepalMapTheme of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<NepalMapTheme>() ??
        NepalMapTheme.fromColorScheme(theme.colorScheme);
  }

  /// Fill of unselected regions.
  final Color regionFill;

  /// Fill of selected regions.
  final Color selectedFill;

  /// Outline of selected regions.
  final Color selectedOutline;

  /// Borders between regions at the shown level.
  final Color borderColor;

  /// Borders of coarser levels, e.g. province borders on a district map.
  final Color parentBorderColor;

  /// The outer edge of the map (the country, or the scope region).
  final Color outlineColor;

  /// Fill of protected areas on local-level maps. They belong to no local
  /// level and can't be tapped.
  final Color protectedAreaFill;

  /// Width of [borderColor] lines, in logical pixels.
  final double borderWidth;

  /// Width of [parentBorderColor] lines, in logical pixels.
  final double parentBorderWidth;

  /// Width of [outlineColor] lines, in logical pixels.
  final double outlineWidth;

  /// Text style of the attribution line. Defaults to the theme's
  /// `labelSmall` in a muted colour.
  final TextStyle? attributionStyle;

  /// The style used when `NepalMap.style` isn't set.
  RegionStyle defaultStyle(Region region, RegionState state) => state.isSelected
      ? RegionStyle(fill: selectedFill, outline: selectedOutline)
      : RegionStyle(fill: regionFill);

  @override
  NepalMapTheme copyWith({
    Color? regionFill,
    Color? selectedFill,
    Color? selectedOutline,
    Color? borderColor,
    Color? parentBorderColor,
    Color? outlineColor,
    Color? protectedAreaFill,
    double? borderWidth,
    double? parentBorderWidth,
    double? outlineWidth,
    TextStyle? attributionStyle,
  }) => NepalMapTheme(
    regionFill: regionFill ?? this.regionFill,
    selectedFill: selectedFill ?? this.selectedFill,
    selectedOutline: selectedOutline ?? this.selectedOutline,
    borderColor: borderColor ?? this.borderColor,
    parentBorderColor: parentBorderColor ?? this.parentBorderColor,
    outlineColor: outlineColor ?? this.outlineColor,
    protectedAreaFill: protectedAreaFill ?? this.protectedAreaFill,
    borderWidth: borderWidth ?? this.borderWidth,
    parentBorderWidth: parentBorderWidth ?? this.parentBorderWidth,
    outlineWidth: outlineWidth ?? this.outlineWidth,
    attributionStyle: attributionStyle ?? this.attributionStyle,
  );

  @override
  NepalMapTheme lerp(NepalMapTheme? other, double t) {
    if (other == null) return this;
    return NepalMapTheme(
      regionFill: Color.lerp(regionFill, other.regionFill, t)!,
      selectedFill: Color.lerp(selectedFill, other.selectedFill, t)!,
      selectedOutline: Color.lerp(selectedOutline, other.selectedOutline, t)!,
      borderColor: Color.lerp(borderColor, other.borderColor, t)!,
      parentBorderColor: Color.lerp(
        parentBorderColor,
        other.parentBorderColor,
        t,
      )!,
      outlineColor: Color.lerp(outlineColor, other.outlineColor, t)!,
      protectedAreaFill: Color.lerp(
        protectedAreaFill,
        other.protectedAreaFill,
        t,
      )!,
      borderWidth: lerpDouble(borderWidth, other.borderWidth, t)!,
      parentBorderWidth: lerpDouble(
        parentBorderWidth,
        other.parentBorderWidth,
        t,
      )!,
      outlineWidth: lerpDouble(outlineWidth, other.outlineWidth, t)!,
      attributionStyle: TextStyle.lerp(
        attributionStyle,
        other.attributionStyle,
        t,
      ),
    );
  }
}
