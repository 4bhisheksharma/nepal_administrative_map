import 'package:flutter_test/flutter_test.dart';
import 'package:nepal_administrative_map/core.dart';

void main() {
  group('MapLanguage.fromLocaleCode', () {
    test('ne gives Nepali, anything else English', () {
      expect(MapLanguage.fromLocaleCode('ne'), MapLanguage.ne);
      expect(MapLanguage.fromLocaleCode('NE'), MapLanguage.ne);
      expect(MapLanguage.fromLocaleCode('en'), MapLanguage.en);
      expect(MapLanguage.fromLocaleCode('hi'), MapLanguage.en);
      expect(MapLanguage.fromLocaleCode(null), MapLanguage.en);
    });
  });

  test('LocalizedName.of', () {
    const name = LocalizedName('Kathmandu', 'काठमाडौं');
    expect(name.of(MapLanguage.en), 'Kathmandu');
    expect(name.of(MapLanguage.ne), 'काठमाडौं');
    expect(name, const LocalizedName('Kathmandu', 'काठमाडौं'));
  });

  group('NepalNumberFormat', () {
    String f(
      num v, {
      MapLanguage lang = MapLanguage.en,
      NumberGrouping? grouping,
      int? decimals,
    }) => NepalNumberFormat.format(
      v,
      language: lang,
      grouping: grouping,
      decimals: decimals,
    );

    test('digits', () {
      expect(NepalNumberFormat.toDevanagariDigits('2081-05'), '२०८१-०५');
      expect(NepalNumberFormat.toLatinDigits('२०८१'), '2081');
    });

    test('Nepali uses Devanagari digits and lakh grouping by default', () {
      expect(f(1744240, lang: MapLanguage.ne), '१७,४४,२४०');
      expect(f(12345678, lang: MapLanguage.ne), '१,२३,४५,६७८');
      expect(f(1234, lang: MapLanguage.ne), '१,२३४');
      expect(f(999, lang: MapLanguage.ne), '९९९');
    });

    test('English uses international grouping by default', () {
      expect(f(1744240), '1,744,240');
      expect(f(1000), '1,000');
      expect(f(0), '0');
    });

    test('grouping can be overridden', () {
      expect(f(1744240, grouping: NumberGrouping.nepali), '17,44,240');
      expect(
        f(
          1744240,
          lang: MapLanguage.ne,
          grouping: NumberGrouping.international,
        ),
        '१,७४४,२४०',
      );
      expect(f(1744240, grouping: NumberGrouping.none), '1744240');
    });

    test('decimals and negatives', () {
      expect(f(-1234.5), '-1,234.50');
      expect(f(1234.567, decimals: 1), '1,234.6');
      expect(f(2.0), '2');
      expect(f(-0.001, decimals: 2), '0.00');
      expect(f(-123456.75, lang: MapLanguage.ne), '-१,२३,४५६.७५');
    });

    test('non-finite values', () {
      expect(f(double.nan), 'NaN');
      expect(f(double.infinity), 'Infinity');
    });
  });

  group('Devanagari', () {
    test('chandrabindu and anusvara compare equal', () {
      expect(
        Devanagari.normalize('काठमाडौँ'),
        Devanagari.normalize('काठमाडौं'),
      );
    });

    test('nukta, zero-width joiners and extra spaces are removed', () {
      expect(Devanagari.normalize(' ड़ ‍क्ष  '), 'ड क्ष');
    });

    test('contains', () {
      expect(Devanagari.contains('पोख'), isTrue);
      expect(Devanagari.contains('Pokhara'), isFalse);
    });
  });

  test('NepalMapStrings', () {
    expect(NepalMapStrings.of(MapLanguage.ne).country, 'नेपाल');
    expect(NepalMapStrings.of(MapLanguage.en).back, 'Back');
    expect(NepalMapStrings.en.copyWith(noData: 'N/A').noData, 'N/A');
    expect(NepalMapStrings.en.copyWith(noData: 'N/A').country, 'Nepal');
  });
}
