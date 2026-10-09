import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/names.dart';
import '../../tool/src/ne_merge.dart';

void main() {
  final rows = readNames('tool/source/names.csv');
  String code(String district, String nameEn) => rows
      .firstWhere(
        (r) =>
            r.level == 'local_level' &&
            r.nameEn == nameEn &&
            rows.any((d) => d.code == r.parentCode && d.nameEn == district),
      )
      .code;

  List<SourceRow> list(String csv) => readSource(parseCsv(csv));

  test('normalises names and types in both scripts', () {
    expect(normalizeEn('Aathrai Tribeni Rural Municipality'), 'aathraitribeni');
    expect(normalizeEn('Pokhara Metropolitan City'), 'pokhara');
    expect(normalizeEn('Butwal Sub-Metropolitan City'), 'butwal');
    expect(shortNe('पोखरा महानगरपालिका'), 'पोखरा');
    expect(shortNe(' आठराई त्रिवेणी गाउँपालिका '), 'आठराई त्रिवेणी');
  });

  test(
    'matches by code, district + name, source spellings and Nepali districts',
    () {
      final result = match(
        rows,
        list('''
code,district,name_en,name_ne
${code('Kaski', 'Pokhara')},,,पोखरा महानगरपालिका
,CHITAWAN,Bharatpur Metropolitan City,भरतपुर महानगरपालिका
,काठमाडौं,Kathmandu,काठमाडौं महानगरपालिका
,Bhojpur,Aamchok,आमचोक गाउँपालिका
,Nowhere,Ghost Town,भूत
'''),
      );
      expect(result.matched[code('Kaski', 'Pokhara')], 'पोखरा');
      expect(result.matched[code('Chitwan', 'Bharatpur')], 'भरतपुर');
      expect(result.matched[code('Kathmandu', 'Kathmandu')], 'काठमाडौं');
      expect(
        result.matched[code('Bhojpur', 'Aamchowk')],
        'आमचोक',
        reason: 'fuzzy spelling',
      );
      expect(result.fuzzy, hasLength(1));
      expect(result.unmatched.single.nameEn, 'Ghost Town');
    },
  );

  test('conflicting names for one region are reported, not applied', () {
    final result = match(
      rows,
      list('''
district,name_en,name_ne
Kaski,Pokhara,पोखरा
Kaski,Pokhara,पोखरा२
'''),
    );
    expect(result.conflicts.keys, [code('Kaski', 'Pokhara')]);
  });

  test('a list without usable columns is rejected', () {
    expect(
      () => list('name_en,name_ne\nPokhara,पोखरा\n'),
      throwsFormatException,
    );
    expect(
      () => list('district,name_en\nKaski,Pokhara\n'),
      throwsFormatException,
    );
  });

  test('writeNames quotes fields with commas', () {
    expect(
      writeNames(
        ['a', 'b'],
        [
          {'a': 'x,y', 'b': 'z'},
        ],
      ),
      'a,b\n"x,y",z\n',
    );
  });
}
