import 'package:flutter_test/flutter_test.dart';
import 'package:nepal_administrative_map/core.dart';

void main() {
  test('fullName in both languages', () {
    expect(
      LocalLevel.pokhara.fullName(MapLanguage.en),
      'Pokhara Metropolitan City',
    );
    expect(District.kaski.fullName(MapLanguage.en), 'Kaski District');
    expect(District.kaski.fullName(MapLanguage.ne), 'कास्की जिल्ला');
    expect(Province.koshi.fullName(MapLanguage.ne), 'कोशी प्रदेश');
    expect(
      ProtectedArea.chitwan.fullName(MapLanguage.en),
      'Chitwan National Park',
    );
    expect(
      ProtectedArea.chitwan.fullName(MapLanguage.ne),
      'चितवन राष्ट्रिय निकुञ्ज',
    );
  });

  test('type and level labels', () {
    expect(LocalLevelType.ruralMunicipality.label.ne, 'गाउँपालिका');
    expect(AdminLevel.district.label.of(MapLanguage.ne), 'जिल्ला');
  });

  test('hierarchy', () {
    expect(Province.gandaki.districts, hasLength(11));
    expect(Province.gandaki.districts, contains(District.kaski));
    expect(District.kaski.localLevels, contains(LocalLevel.pokhara));
    expect(LocalLevel.pokhara.province, Province.gandaki);
    expect(District.kaski.province, Province.gandaki);
    expect(Province.gandaki.province, Province.gandaki);

    final total = Province.values.fold<int>(
      0,
      (n, p) => n + p.localLevels.length,
    );
    expect(total, 753);
    for (final d in District.values) {
      expect(d.localLevels, isNotEmpty, reason: d.name.en);
    }
  });

  test('switch over Region is exhaustive', () {
    String kind(Region r) => switch (r) {
      Province() => 'province',
      District() => 'district',
      LocalLevel() => 'local level',
    };
    expect(kind(District.kaski), 'district');
  });

  group('Nepal gazetteer', () {
    test('lists', () {
      expect(Nepal.provinces, hasLength(7));
      expect(Nepal.regionsAt(AdminLevel.localLevel), hasLength(753));
      expect(Nepal.protectedAreas, hasLength(10));
    });

    test('byCode', () {
      expect(Nepal.byCode('P3'), Province.bagmati);
      expect(Nepal.byCode('D305'), District.kathmandu);
      expect(Nepal.byCode(LocalLevel.pokhara.code), LocalLevel.pokhara);
      expect(Nepal.byCode('nope'), isNull);
      expect(Nepal.byCode('PA01'), isNull);
      expect(
        Nepal.protectedAreaByCode(ProtectedArea.chitwan.code),
        ProtectedArea.chitwan,
      );
    });

    test('aliases keep the source spellings', () {
      expect(Nepal.aliasesOf(District.chitwan.code), contains('Chitawan'));
      expect(
        Nepal.aliasesOf(LocalLevel.pokhara.code),
        contains('Pokhara Lekhnath'),
      );
      expect(Nepal.aliasesOf('P1'), isEmpty);
    });
  });
}
