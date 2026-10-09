import 'map_language.dart';

/// The few UI strings the package shows itself.
///
/// Region names and type labels live on the regions; these are the strings
/// for the map's own UI. Pass your own instance to change the wording.
class NepalMapStrings {
  /// Creates a set of strings.
  const NepalMapStrings({
    required this.country,
    required this.back,
    required this.noData,
  });

  /// The root of the breadcrumb: "Nepal".
  final String country;

  /// Label for going up a level when drilling down.
  final String back;

  /// Shown for regions without a value on a data map.
  final String noData;

  /// English strings.
  static const en = NepalMapStrings(
    country: 'Nepal',
    back: 'Back',
    noData: 'No data',
  );

  /// Nepali strings.
  static const ne = NepalMapStrings(
    country: 'नेपाल',
    back: 'पछाडि',
    noData: 'डाटा उपलब्ध छैन',
  );

  /// The built-in strings for [language].
  static NepalMapStrings of(MapLanguage language) => switch (language) {
    MapLanguage.en => en,
    MapLanguage.ne => ne,
  };

  /// A copy with the given strings replaced.
  NepalMapStrings copyWith({String? country, String? back, String? noData}) =>
      NepalMapStrings(
        country: country ?? this.country,
        back: back ?? this.back,
        noData: noData ?? this.noData,
      );

  @override
  bool operator ==(Object other) =>
      other is NepalMapStrings &&
      other.country == country &&
      other.back == back &&
      other.noData == noData;

  @override
  int get hashCode => Object.hash(country, back, noData);
}
