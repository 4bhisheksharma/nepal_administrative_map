import 'map_language.dart';

/// How digits are grouped with commas.
enum NumberGrouping {
  /// Lakh / crore: `17,44,240`. Last group of three, then groups of two.
  nepali,

  /// Thousands: `1,744,240`.
  international,

  /// No separators: `1744240`.
  none,
}

/// Formats numbers in English or Nepali without depending on `intl`.
abstract final class NepalNumberFormat {
  static const _latin = '0123456789';
  static const _devanagari = '०१२३४५६७८९';

  /// Replaces ASCII digits with Devanagari digits: `'2081'` → `'२०८१'`.
  static String toDevanagariDigits(String input) =>
      _mapDigits(input, _latin, _devanagari);

  /// Replaces Devanagari digits with ASCII digits: `'२०८१'` → `'2081'`.
  static String toLatinDigits(String input) =>
      _mapDigits(input, _devanagari, _latin);

  /// Formats [value] for [language].
  ///
  /// [grouping] defaults to [NumberGrouping.nepali] for Nepali and
  /// [NumberGrouping.international] for English. [decimals] defaults to 0 for
  /// whole numbers and 2 otherwise.
  ///
  /// ```dart
  /// NepalNumberFormat.format(1744240, language: MapLanguage.ne); // १७,४४,२४०
  /// NepalNumberFormat.format(1744240);                           // 1,744,240
  /// ```
  static String format(
    num value, {
    MapLanguage language = MapLanguage.en,
    NumberGrouping? grouping,
    int? decimals,
  }) {
    if (!value.isFinite) return value.toString();
    final places = decimals ?? (value == value.truncate() ? 0 : 2);
    final fixed = value.abs().toStringAsFixed(places);
    final dot = fixed.indexOf('.');
    final whole = dot < 0 ? fixed : fixed.substring(0, dot);
    final fraction = dot < 0 ? '' : fixed.substring(dot);
    final grouped = _group(
      whole,
      grouping ??
          (language == MapLanguage.ne
              ? NumberGrouping.nepali
              : NumberGrouping.international),
    );
    final negative = value < 0 && double.parse(fixed) != 0;
    final result = '${negative ? '-' : ''}$grouped$fraction';
    return language == MapLanguage.ne ? toDevanagariDigits(result) : result;
  }

  static String _group(String digits, NumberGrouping grouping) {
    if (grouping == NumberGrouping.none || digits.length <= 3) return digits;
    if (grouping == NumberGrouping.international) {
      return _groupBy(digits, 3);
    }
    final head = digits.substring(0, digits.length - 3);
    return '${_groupBy(head, 2)},${digits.substring(digits.length - 3)}';
  }

  /// Groups [digits] from the right into chunks of [size].
  static String _groupBy(String digits, int size) {
    final first = digits.length % size;
    final parts = <String>[
      if (first > 0) digits.substring(0, first),
      for (var i = first; i < digits.length; i += size)
        digits.substring(i, i + size),
    ];
    return parts.join(',');
  }

  static String _mapDigits(String input, String from, String to) {
    final out = StringBuffer();
    for (final ch in input.split('')) {
      final i = from.indexOf(ch);
      out.write(i < 0 ? ch : to[i]);
    }
    return out.toString();
  }
}
