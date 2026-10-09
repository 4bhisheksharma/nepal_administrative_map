/// The language the map shows names, labels and numbers in.
enum MapLanguage {
  /// English.
  en,

  /// Nepali (नेपाली), written in Devanagari.
  ne;

  /// Picks the language for a locale language code: `'ne'` gives [ne],
  /// anything else (including `null`) gives [en].
  static MapLanguage fromLocaleCode(String? languageCode) =>
      languageCode?.toLowerCase() == 'ne' ? ne : en;
}
