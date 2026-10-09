import 'map_language.dart';

/// A name in both English and Nepali (Devanagari).
class LocalizedName {
  /// Creates a name from its English and Nepali forms.
  const LocalizedName(this.en, this.ne);

  /// English name, e.g. `Kathmandu`.
  final String en;

  /// Nepali name in Devanagari, e.g. `काठमाडौं`.
  final String ne;

  /// The name in [language].
  String of(MapLanguage language) => switch (language) {
    MapLanguage.en => en,
    MapLanguage.ne => ne,
  };

  @override
  bool operator ==(Object other) =>
      other is LocalizedName && other.en == en && other.ne == ne;

  @override
  int get hashCode => Object.hash(en, ne);

  @override
  String toString() => '$en / $ne';
}
