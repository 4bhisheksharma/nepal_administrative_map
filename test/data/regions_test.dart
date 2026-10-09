import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nepal_administrative_map/core.dart';

void main() {
  final regions = <Region>[
    ...Province.values,
    ...District.values,
    ...LocalLevel.values,
  ];

  test('counts match the official totals', () {
    expect(Province.values, hasLength(7));
    expect(District.values, hasLength(77));
    expect(LocalLevel.values, hasLength(753));
    expect(ProtectedArea.values, hasLength(10));
  });

  test('local level types match the official totals', () {
    int count(LocalLevelType t) =>
        LocalLevel.values.where((l) => l.type == t).length;
    expect(count(LocalLevelType.metropolitan), 6);
    expect(count(LocalLevelType.subMetropolitan), 11);
    expect(count(LocalLevelType.municipality), 276);
    expect(count(LocalLevelType.ruralMunicipality), 460);
  });

  test('codes are unique', () {
    final codes = [
      ...regions.map((r) => r.code),
      ...ProtectedArea.values.map((p) => p.code),
    ];
    expect(codes.toSet(), hasLength(codes.length));
  });

  test('codes encode the hierarchy', () {
    for (final d in District.values) {
      expect(d.code, startsWith('D${d.province.number}'));
    }
    for (final l in LocalLevel.values) {
      expect(l.code.substring(1, 4), l.district.code.substring(1));
    }
  });

  test('every province has districts', () {
    for (final p in Province.values) {
      expect(District.values.where((d) => d.province == p), isNotEmpty);
    }
  });

  test('known regions', () {
    expect(LocalLevel.pokhara.district, District.kaski);
    expect(LocalLevel.pokhara.type, LocalLevelType.metropolitan);
    expect(District.kaski.province, Province.gandaki);
    expect(District.kathmandu.name.ne, 'काठमाडौं');
    expect(Province.sudurpashchim.number, 7);
  });

  test('map asset has exactly one feature per region', () {
    final topo = jsonDecode(
      File('assets/maps/nepal.topo.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    List<String> ids(String object) {
      final objects = topo['objects'] as Map<String, dynamic>;
      final o = objects[object] as Map<String, dynamic>;
      return [
        for (final g in o['geometries'] as List) (g as Map)['id'] as String,
      ];
    }

    expect(
      ids('provinces'),
      Province.values.map((r) => r.code).toList()..sort(),
    );
    expect(
      ids('districts'),
      District.values.map((r) => r.code).toList()..sort(),
    );
    expect(
      ids('local_levels'),
      LocalLevel.values.map((r) => r.code).toList()..sort(),
    );
    expect(
      ids('protected_areas'),
      ProtectedArea.values.map((r) => r.code).toList()..sort(),
    );
  });
}
