import 'package:flutter/material.dart';

import '../i18n/localized_name.dart';
import '../i18n/map_language.dart';
import '../i18n/nepal_map_strings.dart';
import '../i18n/nepal_number_format.dart';
import '../rendering/style/color_scale.dart';
import 'choropleth.dart';

/// Explains a [ColorScale]: a gradient bar for continuous scales, or
/// swatches for threshold and categorical scales. Numbers follow the
/// language (Devanagari digits and lakh grouping in Nepali).
///
/// A [NepalMap] with a [Choropleth] shows one automatically; use this
/// widget to place a legend yourself.
class NepalMapLegend extends StatelessWidget {
  /// Creates a legend for [scale]. [extent] is the data range, needed by
  /// continuous scales without a fixed domain.
  const NepalMapLegend({
    super.key,
    required this.scale,
    this.extent,
    this.title,
    this.language,
    this.formatter,
    this.grouping,
    this.showNoData = false,
    this.noDataColor,
    this.strings,
  });

  /// A legend for [choropleth].
  factory NepalMapLegend.of(
    Choropleth choropleth, {
    Key? key,
    MapLanguage? language,
    bool showNoData = false,
    Color? noDataColor,
  }) => NepalMapLegend(
    key: key,
    scale: choropleth.scale,
    extent: choropleth.extent,
    title: choropleth.title,
    language: language,
    formatter: choropleth.formatter,
    grouping: choropleth.grouping,
    showNoData: showNoData,
    noDataColor: noDataColor,
  );

  /// The scale to explain.
  final ColorScale scale;

  /// The data range for continuous scales without a fixed domain.
  final ScaleDomain? extent;

  /// Heading, e.g. "Population" / "जनसंख्या".
  final LocalizedName? title;

  /// Language of the title and numbers. Defaults to the app locale.
  final MapLanguage? language;

  /// Formats tick values. Defaults to [NepalNumberFormat].
  final ValueFormatter? formatter;

  /// Digit grouping for the default formatter.
  final NumberGrouping? grouping;

  /// Whether to add a "No data" swatch.
  final bool showNoData;

  /// Colour of the "No data" swatch.
  final Color? noDataColor;

  /// Replaces the built-in strings ("No data").
  final NepalMapStrings? strings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang =
        language ??
        MapLanguage.fromLocaleCode(
          Localizations.maybeLocaleOf(context)?.languageCode,
        );
    String fmt(num v) =>
        formatter?.call(v, lang) ??
        NepalNumberFormat.format(v, language: lang, grouping: grouping);
    final textStyle = theme.textTheme.labelSmall!;
    final s = strings ?? NepalMapStrings.of(lang);

    final body = switch (scale) {
      final SequentialScale seq => () {
        final d = seq.domain ?? extent ?? (min: 0, max: 1);
        return _gradient(
          [
            for (var i = 0; i <= 8; i++)
              seq.colorOf(d.min + (d.max - d.min) * i / 8, d)!,
          ],
          [fmt(d.min), fmt(d.max)],
          textStyle,
        );
      }(),
      final DivergingScale div => () {
        final d = div.domain ?? extent ?? (min: 0, max: 1);
        final mid = div.midOf(d);
        num at(double t) => t < 0.5
            ? d.min + (mid - d.min) * t * 2
            : mid + (d.max - mid) * (t - 0.5) * 2;
        return _gradient(
          [for (var i = 0; i <= 8; i++) div.colorOf(at(i / 8), d)!],
          [fmt(d.min), fmt(mid), fmt(d.max)],
          textStyle,
        );
      }(),
      ThresholdScale(:final breaks, :final colors) => _swatches([
        for (var i = 0; i < colors.length; i++)
          (
            colors[i],
            i == 0
                ? '< ${fmt(breaks.first)}'
                : i == colors.length - 1
                ? '≥ ${fmt(breaks.last)}'
                : '${fmt(breaks[i - 1])} – ${fmt(breaks[i])}',
          ),
      ], textStyle),
      CategoricalScale(:final colors, :final labels) => _swatches([
        for (final MapEntry(:key, :value) in colors.entries)
          (value, labels?[key]?.of(lang) ?? key.toString()),
      ], textStyle),
    };

    return Material(
      color: theme.colorScheme.surface.withValues(alpha: 0.92),
      elevation: 1,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: DefaultTextStyle(
          style: textStyle,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title case final t?)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    t.of(lang),
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              body,
              if (showNoData)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: _swatches([
                    (
                      noDataColor ?? theme.colorScheme.surfaceContainer,
                      s.noData,
                    ),
                  ], textStyle),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// A gradient bar with tick labels under it: at least 160 px wide, and
  /// wider if the labels need it.
  static Widget _gradient(
    List<Color> stops,
    List<String> ticks,
    TextStyle style,
  ) => IntrinsicWidth(
    child: ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 160),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 10,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: LinearGradient(colors: stops),
            ),
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            spacing: 12,
            children: [for (final t in ticks) Text(t, style: style)],
          ),
        ],
      ),
    ),
  );

  static Widget _swatches(List<(Color, String)> items, TextStyle style) =>
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (color, label) in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1.5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(label, style: style),
                ],
              ),
            ),
        ],
      );
}
