import 'package:flutter/material.dart';

import '../data/gazetteer/nepal.dart';
import '../data/models/region.dart';
import '../i18n/map_language.dart';
import '../i18n/nepal_map_strings.dart';
import 'nepal_map_controller.dart';

/// A search box for places, in English or Nepali, with suggestions as you
/// type.
///
/// With a [controller], picking a place highlights it and zooms the map to
/// it. Pass [onSelected] to do something else instead.
class NepalMapSearchField extends StatelessWidget {
  /// Creates a search field.
  const NepalMapSearchField({
    super.key,
    this.controller,
    this.onSelected,
    this.levels,
    this.limit = 8,
    this.language,
    this.strings,
    this.decoration,
  });

  /// The map to highlight and zoom on selection.
  final NepalMapController? controller;

  /// Called with the picked region, replacing the highlight-and-zoom.
  final ValueChanged<Region>? onSelected;

  /// Only suggest these levels. Defaults to all.
  final Set<AdminLevel>? levels;

  /// Most suggestions to show.
  final int limit;

  /// Language of the suggestions. Defaults to the controller's language,
  /// then the app locale.
  final MapLanguage? language;

  /// Replaces the built-in strings (the placeholder).
  final NepalMapStrings? strings;

  /// Decoration of the text field.
  final InputDecoration? decoration;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    if (controller == null) return _build(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final lang =
        language ??
        controller?.language ??
        MapLanguage.fromLocaleCode(
          Localizations.maybeLocaleOf(context)?.languageCode,
        );
    final s = strings ?? NepalMapStrings.of(lang);
    return Autocomplete<Region>(
      optionsBuilder: (value) =>
          Nepal.search(value.text, levels: levels, limit: limit),
      displayStringForOption: (region) => region.fullName(lang),
      onSelected: (region) {
        FocusScope.of(context).unfocus();
        if (onSelected case final callback?) {
          callback(region);
        } else {
          controller
            ?..highlight([region])
            ..zoomTo(region);
        }
      },
      fieldViewBuilder: (context, text, focusNode, onSubmitted) => TextField(
        controller: text,
        focusNode: focusNode,
        onSubmitted: (_) => onSubmitted(),
        decoration:
            decoration ??
            InputDecoration(
              hintText: s.searchHint,
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
      ),
      optionsViewBuilder: (context, select, options) => Align(
        alignment: AlignmentDirectional.topStart,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320, maxWidth: 360),
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: [
                for (final region in options)
                  ListTile(
                    dense: true,
                    title: Text(region.fullName(lang)),
                    subtitle: switch (region) {
                      Province() => null,
                      District(:final province) => Text(
                        province.fullName(lang),
                      ),
                      LocalLevel(:final district) => Text(
                        '${district.fullName(lang)}, ${district.province.fullName(lang)}',
                      ),
                    },
                    onTap: () => select(region),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
