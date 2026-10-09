/// Text helpers for matching Devanagari input.
abstract final class Devanagari {
  static final _whitespace = RegExp(r'\s+');

  /// Normalises Nepali text so that common spelling variants compare equal.
  ///
  /// - chandrabindu (ँ) is treated as anusvara (ं)
  /// - nukta (़) and zero-width joiners are removed
  /// - whitespace is collapsed and trimmed
  ///
  /// `normalize('काठमाडौँ') == normalize('काठमाडौं')`.
  static String normalize(String input) => input
      .replaceAll('ँ', 'ं')
      .replaceAll(RegExp('[़‌‍]'), '')
      .replaceAll(_whitespace, ' ')
      .trim();

  /// Whether [input] contains any Devanagari character.
  static bool contains(String input) =>
      input.runes.any((r) => r >= 0x0900 && r <= 0x097F);
}
