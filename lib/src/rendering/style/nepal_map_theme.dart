import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../data/models/region.dart';
import 'region_style.dart';

/// Colours, line widths and label style of a [NepalMap].
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
    required this.hoverFill,
    required this.selectedFill,
    required this.selectedOutline,
    required this.highlightOutline,
    required this.borderColor,
    required this.parentBorderColor,
    required this.outlineColor,
    required this.protectedAreaFill,
    required this.noDataFill,
    required this.protectedAreaOverlay,
    required this.labelColor,
    required this.labelHaloColor,
    this.borderWidth = 0.5,
    this.parentBorderWidth = 1.2,
    this.outlineWidth = 1.2,
    this.labelStyle,
    this.attributionStyle,
  });

  /// Default theme for [scheme].
  factory NepalMapTheme.fromColorScheme(ColorScheme scheme) => NepalMapTheme(
    regionFill: scheme.surfaceContainerHighest,
    hoverFill: Color.alphaBlend(
      scheme.primary.withValues(alpha: 0.12),
      scheme.surfaceContainerHighest,
    ),
    selectedFill: scheme.primaryContainer,
    selectedOutline: scheme.primary,
    highlightOutline: scheme.tertiary,
    borderColor: scheme.surface,
    parentBorderColor: scheme.outline,
    outlineColor: scheme.outline,
    protectedAreaFill: scheme.surfaceContainerLow,
    noDataFill: Color.alphaBlend(
      scheme.outlineVariant.withValues(alpha: 0.35),
      scheme.surface,
    ),
    protectedAreaOverlay: scheme.tertiary,
    labelColor: scheme.onSurface,
    labelHaloColor: scheme.surfaceContainerHighest,
  );

  /// The theme a map in [context] uses when `NepalMap.theme` isn't set.
  static NepalMapTheme of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<NepalMapTheme>() ??
        NepalMapTheme.fromColorScheme(theme.colorScheme);
  }

  /// Fill of regions in their normal state.
  final Color regionFill;

  /// Fill of the region under the mouse.
  final Color hoverFill;

  /// Fill of selected regions.
  final Color selectedFill;

  /// Outline of selected regions.
  final Color selectedOutline;

  /// Outline of regions highlighted with `NepalMapController.highlight`.
  final Color highlightOutline;

  /// Borders between regions at the shown level.
  final Color borderColor;

  /// Borders of coarser levels, e.g. province borders on a district map.
  final Color parentBorderColor;

  /// The outer edge of the map (the country, or the scope region).
  final Color outlineColor;

  /// Fill of protected areas on local-level maps. They belong to no local
  /// level and can't be tapped.
  final Color protectedAreaFill;

  /// Fill of regions without a value on a choropleth map.
  final Color noDataFill;

  /// Colour of the protected-area overlay (`showProtectedAreas`): its
  /// outline, and a lighter tint and hatching inside.
  final Color protectedAreaOverlay;

  /// Colour of region labels.
  final Color labelColor;

  /// Outline drawn around label text so it stays readable over borders.
  final Color labelHaloColor;

  /// Width of [borderColor] lines, in logical pixels.
  final double borderWidth;

  /// Width of [parentBorderColor] lines, in logical pixels.
  final double parentBorderWidth;

  /// Width of [outlineColor] lines, in logical pixels.
  final double outlineWidth;

  /// Font, size and weight of labels. Its colour is replaced by
  /// [labelColor]. Defaults to 11 px, medium weight.
  ///
  /// Set `fontFamily` here for a consistent Devanagari font across
  /// platforms (e.g. from `google_fonts`).
  final TextStyle? labelStyle;

  /// Text style of the attribution line. Defaults to the theme's
  /// `labelSmall` in a muted colour.
  final TextStyle? attributionStyle;

  /// The style used when `NepalMap.style` isn't set.
  RegionStyle defaultStyle(Region region, RegionState state) => RegionStyle(
    fill: state.isSelected
        ? selectedFill
        : state.isHovered
        ? hoverFill
        : regionFill,
    outline: state.isSelected
        ? selectedOutline
        : state.isHighlighted
        ? highlightOutline
        : null,
  );

  @override
  NepalMapTheme copyWith({
    Color? regionFill,
    Color? hoverFill,
    Color? selectedFill,
    Color? selectedOutline,
    Color? highlightOutline,
    Color? borderColor,
    Color? parentBorderColor,
    Color? outlineColor,
    Color? protectedAreaFill,
    Color? noDataFill,
    Color? protectedAreaOverlay,
    Color? labelColor,
    Color? labelHaloColor,
    double? borderWidth,
    double? parentBorderWidth,
    double? outlineWidth,
    TextStyle? labelStyle,
    TextStyle? attributionStyle,
  }) => NepalMapTheme(
    regionFill: regionFill ?? this.regionFill,
    hoverFill: hoverFill ?? this.hoverFill,
    selectedFill: selectedFill ?? this.selectedFill,
    selectedOutline: selectedOutline ?? this.selectedOutline,
    highlightOutline: highlightOutline ?? this.highlightOutline,
    borderColor: borderColor ?? this.borderColor,
    parentBorderColor: parentBorderColor ?? this.parentBorderColor,
    outlineColor: outlineColor ?? this.outlineColor,
    protectedAreaFill: protectedAreaFill ?? this.protectedAreaFill,
    noDataFill: noDataFill ?? this.noDataFill,
    protectedAreaOverlay: protectedAreaOverlay ?? this.protectedAreaOverlay,
    labelColor: labelColor ?? this.labelColor,
    labelHaloColor: labelHaloColor ?? this.labelHaloColor,
    borderWidth: borderWidth ?? this.borderWidth,
    parentBorderWidth: parentBorderWidth ?? this.parentBorderWidth,
    outlineWidth: outlineWidth ?? this.outlineWidth,
    labelStyle: labelStyle ?? this.labelStyle,
    attributionStyle: attributionStyle ?? this.attributionStyle,
  );

  @override
  NepalMapTheme lerp(NepalMapTheme? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    double d(double a, double b) => lerpDouble(a, b, t)!;
    return NepalMapTheme(
      regionFill: c(regionFill, other.regionFill),
      hoverFill: c(hoverFill, other.hoverFill),
      selectedFill: c(selectedFill, other.selectedFill),
      selectedOutline: c(selectedOutline, other.selectedOutline),
      highlightOutline: c(highlightOutline, other.highlightOutline),
      borderColor: c(borderColor, other.borderColor),
      parentBorderColor: c(parentBorderColor, other.parentBorderColor),
      outlineColor: c(outlineColor, other.outlineColor),
      protectedAreaFill: c(protectedAreaFill, other.protectedAreaFill),
      noDataFill: c(noDataFill, other.noDataFill),
      protectedAreaOverlay: c(protectedAreaOverlay, other.protectedAreaOverlay),
      labelColor: c(labelColor, other.labelColor),
      labelHaloColor: c(labelHaloColor, other.labelHaloColor),
      borderWidth: d(borderWidth, other.borderWidth),
      parentBorderWidth: d(parentBorderWidth, other.parentBorderWidth),
      outlineWidth: d(outlineWidth, other.outlineWidth),
      labelStyle: TextStyle.lerp(labelStyle, other.labelStyle, t),
      attributionStyle: TextStyle.lerp(
        attributionStyle,
        other.attributionStyle,
        t,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NepalMapTheme &&
      other.regionFill == regionFill &&
      other.hoverFill == hoverFill &&
      other.selectedFill == selectedFill &&
      other.selectedOutline == selectedOutline &&
      other.highlightOutline == highlightOutline &&
      other.borderColor == borderColor &&
      other.parentBorderColor == parentBorderColor &&
      other.outlineColor == outlineColor &&
      other.protectedAreaFill == protectedAreaFill &&
      other.noDataFill == noDataFill &&
      other.protectedAreaOverlay == protectedAreaOverlay &&
      other.labelColor == labelColor &&
      other.labelHaloColor == labelHaloColor &&
      other.borderWidth == borderWidth &&
      other.parentBorderWidth == parentBorderWidth &&
      other.outlineWidth == outlineWidth &&
      other.labelStyle == labelStyle &&
      other.attributionStyle == attributionStyle;

  @override
  int get hashCode => Object.hash(
    regionFill,
    hoverFill,
    selectedFill,
    selectedOutline,
    highlightOutline,
    borderColor,
    parentBorderColor,
    outlineColor,
    protectedAreaFill,
    noDataFill,
    protectedAreaOverlay,
    labelColor,
    labelHaloColor,
    borderWidth,
    parentBorderWidth,
    outlineWidth,
    labelStyle,
    attributionStyle,
  );
}
