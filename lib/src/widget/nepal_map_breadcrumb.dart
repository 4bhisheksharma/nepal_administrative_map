import 'package:flutter/material.dart';

import '../data/models/region.dart';
import '../i18n/map_language.dart';
import '../i18n/nepal_map_strings.dart';
import 'nepal_map_controller.dart';

/// Shows where a drill-down map is, e.g. `Nepal › Gandaki Province › Kaski`,
/// with each level above the current one tappable to go back to it.
///
/// ```dart
/// Column(children: [
///   NepalMapBreadcrumb(controller: controller),
///   Expanded(child: NepalMap(controller: controller, drillDown: true)),
/// ])
/// ```
class NepalMapBreadcrumb extends StatelessWidget {
  /// Creates a breadcrumb for the map driven by [controller].
  const NepalMapBreadcrumb({
    super.key,
    required this.controller,
    this.language,
    this.strings,
    this.style,
    this.separator = '›',
  });

  /// The controller of the map to follow.
  final NepalMapController controller;

  /// The language. Defaults to the controller's language, then the app
  /// locale.
  final MapLanguage? language;

  /// Replaces the built-in strings ("Nepal").
  final NepalMapStrings? strings;

  /// Text style. Defaults to the theme's `titleSmall`.
  final TextStyle? style;

  /// Text between segments.
  final String separator;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final lang =
          controller.language ??
          language ??
          MapLanguage.fromLocaleCode(
            Localizations.maybeLocaleOf(context)?.languageCode,
          );
      final s = strings ?? NepalMapStrings.of(lang);
      final segments = <(String, Region?)>[
        (s.country, null),
        ...switch (controller.scope) {
          null => const <(String, Region?)>[],
          final Province p => [(p.fullName(lang), p)],
          final District d => [
            (d.province.fullName(lang), d.province),
            (d.name.of(lang), d),
          ],
          final LocalLevel l => [(l.name.of(lang), l)],
        },
      ];
      final theme = Theme.of(context);
      final textStyle = style ?? theme.textTheme.titleSmall;
      return Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final (i, (label, target)) in segments.indexed) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  separator,
                  style: textStyle?.copyWith(color: theme.colorScheme.outline),
                ),
              ),
            if (i == segments.length - 1)
              Text(
                label,
                style: textStyle?.copyWith(fontWeight: FontWeight.w600),
              )
            else
              InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: () => controller.drillTo(target),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 4,
                  ),
                  child: Text(
                    label,
                    style: textStyle?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
          ],
        ],
      );
    },
  );
}
