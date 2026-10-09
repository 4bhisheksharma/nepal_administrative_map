import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../data/gazetteer/nepal.dart';
import '../data/models/region.dart';
import '../i18n/localized_name.dart';
import '../i18n/map_language.dart';
import '../i18n/nepal_number_format.dart';
import '../rendering/style/color_scale.dart';
import '../rendering/style/nepal_map_theme.dart';
import '../rendering/style/region_style.dart';

/// Formats a data value for tooltips and the legend.
typedef ValueFormatter = String Function(Object value, MapLanguage language);

/// Data to colour a map by: one value per region and a [ColorScale].
///
/// ```dart
/// NepalMap(
///   level: AdminLevel.district,
///   choropleth: Choropleth(
///     values: {District.kathmandu: 1744240, District.lalitpur: 548401},
///     scale: ColorScale.sequential(Colors.yellow.shade100, Colors.red.shade800),
///     title: LocalizedName('Population', 'जनसंख्या'),
///   ),
/// )
/// ```
@immutable
class Choropleth {
  /// Creates a choropleth from values keyed by region.
  const Choropleth({
    required this.values,
    required this.scale,
    this.title,
    this.formatter,
    this.grouping,
    this.showLegend = true,
    this.legendAlignment = AlignmentDirectional.bottomStart,
  });

  /// Creates a choropleth from values keyed by region code (e.g. `D305`),
  /// for data joined from a CSV file or an API.
  ///
  /// Unknown codes fail an assertion in debug builds and are skipped in
  /// release builds.
  factory Choropleth.byCode(
    Map<String, Object> values, {
    required ColorScale scale,
    LocalizedName? title,
    ValueFormatter? formatter,
    NumberGrouping? grouping,
    bool showLegend = true,
    AlignmentGeometry legendAlignment = AlignmentDirectional.bottomStart,
  }) {
    final byRegion = <Region, Object>{};
    for (final MapEntry(:key, :value) in values.entries) {
      final region = Nepal.byCode(key);
      assert(region != null, 'Unknown region code "$key"');
      if (region != null) byRegion[region] = value;
    }
    return Choropleth(
      values: byRegion,
      scale: scale,
      title: title,
      formatter: formatter,
      grouping: grouping,
      showLegend: showLegend,
      legendAlignment: legendAlignment,
    );
  }

  /// The value of each region. Regions without one get the theme's
  /// no-data colour.
  final Map<Region, Object> values;

  /// Maps values to colours.
  final ColorScale scale;

  /// What the values are, e.g. "Population" / "जनसंख्या". Shown in the
  /// legend and tooltips.
  final LocalizedName? title;

  /// Formats values for tooltips and the legend. Defaults to
  /// [NepalNumberFormat] for numbers and `toString()` otherwise.
  final ValueFormatter? formatter;

  /// Digit grouping for the default formatter. Defaults to lakh/crore in
  /// Nepali and thousands in English.
  final NumberGrouping? grouping;

  /// Whether the map shows a legend.
  final bool showLegend;

  /// Where on the map the legend goes.
  final AlignmentGeometry legendAlignment;

  /// The range of the numeric values, used by continuous scales without a
  /// fixed domain.
  ScaleDomain get extent =>
      ColorScale.extentOf(values.values) ?? (min: 0, max: 0);

  /// The fill colour for [region], or `null` if it has no value or the scale
  /// has no colour for it.
  Color? colorOf(Region region) => scale.colorOf(values[region], extent);

  /// [value] formatted for [language].
  String format(Object value, MapLanguage language) =>
      formatter?.call(value, language) ??
      (value is num
          ? NepalNumberFormat.format(
              value,
              language: language,
              grouping: grouping,
            )
          : value.toString());

  /// The style a map uses for this choropleth when `NepalMap.style` isn't
  /// set: the scale's colour (or [NepalMapTheme.noDataFill]), darkened a
  /// little on hover, with the theme's selection and highlight outlines.
  RegionStyleBuilder defaultStyle(NepalMapTheme theme) {
    final range = extent;
    return (region, state) {
      var fill = scale.colorOf(state.value, range) ?? theme.noDataFill;
      if (state.isHovered) {
        fill = Color.alphaBlend(theme.labelColor.withValues(alpha: 0.12), fill);
      }
      return RegionStyle(
        fill: fill,
        outline: state.isFocused
            ? theme.focusOutline
            : state.isSelected
            ? theme.selectedOutline
            : state.isHighlighted
            ? theme.highlightOutline
            : null,
        outlineWidth: state.isFocused ? 3 : 2,
      );
    };
  }

  @override
  bool operator ==(Object other) =>
      other is Choropleth &&
      mapEquals(other.values, values) &&
      other.scale == scale &&
      other.title == title &&
      other.formatter == formatter &&
      other.grouping == grouping &&
      other.showLegend == showLegend &&
      other.legendAlignment == legendAlignment;

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(values.keys),
    scale,
    title,
    grouping,
    showLegend,
    legendAlignment,
  );
}
