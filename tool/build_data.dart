// Builds the package's map data from the raw OKNP boundaries.
//
//   dart run tool/build_data.dart            # development build
//   dart run tool/build_data.dart --strict   # release build: Nepali names required
//
// Inputs:  tool/source/raw/oknp_local_levels.topojson, tool/source/names.csv
// Outputs: assets/maps/nepal.topo.json, lib/src/data/models/region.g.dart
//
// Requires Node.js; mapshaper is fetched through npx at a pinned version.
// See tool/README.md.

import 'dart:convert';
import 'dart:io';

import 'src/codegen.dart';
import 'src/names.dart';

const mapshaperVersion = '0.7.81';
const defaultSimplify = '40%';

const rawPath = 'tool/source/raw/oknp_local_levels.topojson';
const namesPath = 'tool/source/names.csv';
const assetPath = 'assets/maps/nepal.topo.json';
const regionsPath = 'lib/src/data/models/region.g.dart';
const workDir = 'build/map_data';

const expectedCounts = {
  'province': 7,
  'district': 77,
  'local_level': 753,
  'protected_area': 10,
};

/// Output object name in the topology for each level.
const objectNames = {
  'province': 'provinces',
  'district': 'districts',
  'local_level': 'local_levels',
  'protected_area': 'protected_areas',
};

final _devanagari = RegExp('^[ऀ-ॿ‌‍ ()\\-]+\$');

Future<void> main(List<String> args) async {
  if (!File('pubspec.yaml').existsSync() || !File(rawPath).existsSync()) {
    _fail(['Run from the package root: dart run tool/build_data.dart']);
  }
  final strict = args.contains('--strict');
  final simplify =
      args
          .firstWhere((a) => a.startsWith('--simplify='), orElse: () => '')
          .split('=')
          .elementAtOrNull(1) ??
      defaultSimplify;

  final rows = readNames(namesPath);
  final byCode = {for (final r in rows) r.code: r};
  final warnings = <String>[];
  _validateNames(rows, byCode, strict: strict, warnings: warnings);

  // 1. Tag every raw feature with its codes.
  final raw =
      jsonDecode(File(rawPath).readAsStringSync()) as Map<String, dynamic>;
  final paDistricts = _tagFeatures(raw, rows, byCode);
  Directory(workDir).createSync(recursive: true);
  File('$workDir/stage1.json').writeAsStringSync(jsonEncode(raw));

  // 2. Simplify, dissolve and build the shared topology.
  await _runMapshaper(simplify);

  // 3. Keep only codes, check the result and write the asset.
  final topo = jsonDecode(
    File('$workDir/out.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  _finishTopology(topo, rows);
  File(assetPath)
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(jsonEncode(topo));

  // 4. Generate the typed gazetteer.
  File(regionsPath).writeAsStringSync(generateRegions(rows, paDistricts));
  final fmt = await Process.run('dart', ['format', regionsPath]);
  if (fmt.exitCode != 0) _fail(['dart format failed:\n${fmt.stderr}']);

  _report(topo, rows, simplify, warnings);
}

void _validateNames(
  List<NameRow> rows,
  Map<String, NameRow> byCode, {
  required bool strict,
  required List<String> warnings,
}) {
  final errors = <String>[];
  if (byCode.length != rows.length) errors.add('Duplicate codes in names.csv');

  const parentLevel = {
    'province': null,
    'district': 'province',
    'local_level': 'district',
    'protected_area': null,
  };
  var missingNe = 0;
  for (final r in rows) {
    final where = '${r.code} (${r.nameEn})';
    if (!levels.contains(r.level)) errors.add('$where: unknown level');
    if (!validTypes[r.level]!.contains(r.type)) {
      errors.add('$where: invalid type "${r.type}" for ${r.level}');
    }
    final wantParent = parentLevel[r.level];
    if (wantParent == null) {
      if (r.parentCode.isNotEmpty) errors.add('$where: must not have a parent');
    } else if (byCode[r.parentCode]?.level != wantParent) {
      errors.add('$where: parent "${r.parentCode}" is not a $wantParent');
    }
    if (r.nameEn.trim().isEmpty) errors.add('$where: empty name_en');
    if (!neStatuses.contains(r.neStatus)) {
      errors.add('$where: ne_status must be one of $neStatuses');
    }
    if (r.nameNe.isEmpty) {
      missingNe++;
      if (r.neStatus != 'missing') {
        errors.add('$where: empty name_ne but ne_status is ${r.neStatus}');
      }
    } else {
      if (!_devanagari.hasMatch(r.nameNe)) {
        errors.add('$where: name_ne "${r.nameNe}" is not Devanagari');
      }
      if (r.neStatus == 'missing') {
        errors.add('$where: has name_ne but ne_status is missing');
      }
    }
  }
  for (final MapEntry(key: level, value: n) in expectedCounts.entries) {
    final got = rows.where((r) => r.level == level).length;
    if (got != n) errors.add('Expected $n ${level}s in names.csv, found $got');
  }
  if (missingNe > 0) {
    final msg =
        '$missingNe regions have no Nepali name (English is used '
        'as a fallback)';
    strict ? errors.add(msg) : warnings.add(msg);
  }
  if (errors.isNotEmpty) _fail(errors);
}

/// Replaces each raw feature's properties with `{code, d, p, k}` and returns
/// the districts each protected area covers.
Map<String, List<String>> _tagFeatures(
  Map<String, dynamic> raw,
  List<NameRow> rows,
  Map<String, NameRow> byCode,
) {
  final errors = <String>[];
  final districtByRaw = {
    for (final r in rows.where((r) => r.level == 'district'))
      for (final k in r.sourceKeys) k: r,
  };
  final rowByKey = <String, NameRow>{};
  for (final r in rows.where(
    (r) => r.level == 'local_level' || r.level == 'protected_area',
  )) {
    for (final k in r.sourceKeys) {
      if (rowByKey.containsKey(k)) errors.add('Source key "$k" used twice');
      rowByKey[k] = r;
    }
  }

  final matched = <String>{};
  final paDistricts = <String, Set<String>>{};
  for (final g in _geometries(raw, 'local_levels')) {
    final p = g['properties'] as Map<String, dynamic>;
    final key = '${p['DISTRICT']}|${p['GaPa_NaPa']}';
    final row = rowByKey[key];
    final district = districtByRaw[p['DISTRICT']];
    if (row == null || district == null) {
      errors.add('Raw feature "$key" has no row in names.csv');
      continue;
    }
    if (row.level == 'local_level' && row.parentCode != district.code) {
      errors.add(
        '${row.code}: parent is ${row.parentCode} but the raw data '
        'puts it in ${district.code}',
      );
    }
    if (row.level == 'protected_area') {
      (paDistricts[row.code] ??= {}).add(district.code);
    }
    matched.add(row.code);
    g['properties'] = {
      'code': row.code,
      'd': district.code,
      'p': district.parentCode,
      'k': row.level == 'local_level' ? 'll' : 'pa',
    };
  }
  for (final r in rows.where(
    (r) => r.level == 'local_level' || r.level == 'protected_area',
  )) {
    if (!matched.contains(r.code)) {
      errors.add('${r.code} (${r.nameEn}) matches no raw feature');
    }
  }
  if (errors.isNotEmpty) _fail(errors);
  return {
    for (final MapEntry(:key, :value) in paDistricts.entries)
      key: value.toList()..sort(),
  };
}

Future<void> _runMapshaper(String simplify) async {
  final args = [
    '--yes', 'mapshaper@$mapshaperVersion',
    '-i', '$workDir/stage1.json',
    // Simplifying the shared arcs once keeps every level's borders aligned.
    '-simplify', 'visvalingam', 'weighted', simplify, 'keep-shapes',
    '-dissolve', 'p', '+', 'name=provinces',
    '-target', 'local_levels',
    '-dissolve', 'd', '+', 'name=districts',
    '-target', 'local_levels',
    '-filter', "k === 'pa'", '+', 'name=protected_areas',
    '-target', 'protected_areas',
    '-dissolve', 'code',
    '-target', 'local_levels',
    '-filter', "k === 'll'",
    // Joins municipalities that the source splits into two polygons.
    '-dissolve', 'code',
    '-target', 'provinces,districts,local_levels,protected_areas',
    '-o', '$workDir/out.json', 'format=topojson', 'combine-layers',
    'quantization=100000', 'force',
  ];
  stdout.writeln('Running mapshaper $mapshaperVersion (simplify $simplify)…');
  final result = await Process.run('npx', args, runInShell: true);
  if (result.exitCode != 0) {
    _fail(['mapshaper failed:\n${result.stdout}\n${result.stderr}']);
  }
}

/// Moves each feature's code to the TopoJSON `id`, drops all other
/// properties, sorts features by code and checks the counts.
void _finishTopology(Map<String, dynamic> topo, List<NameRow> rows) {
  final errors = <String>[];
  const codeField = {
    'provinces': 'p',
    'districts': 'd',
    'local_levels': 'code',
    'protected_areas': 'code',
  };
  final objects = topo['objects'] as Map<String, dynamic>;
  for (final MapEntry(key: level, value: object) in objectNames.entries) {
    final geometries = objects.containsKey(object)
        ? _geometries(topo, object)
        : <Map<String, dynamic>>[];
    for (final g in geometries) {
      g['id'] = (g['properties'] as Map)[codeField[object]];
      g.remove('properties');
    }
    geometries.sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));

    final want = rows.where((r) => r.level == level).map((r) => r.code).toSet();
    final got = geometries.map((g) => g['id'] as String).toList();
    if (got.length != want.length || !want.containsAll(got)) {
      errors.add(
        '$object: expected ${want.length} features matching '
        'names.csv, got ${got.length}',
      );
    }
  }
  if (errors.isNotEmpty) _fail(errors);
}

void _report(
  Map<String, dynamic> topo,
  List<NameRow> rows,
  String simplify,
  List<String> warnings,
) {
  final arcs = topo['arcs'] as List;
  final points = arcs.fold<int>(0, (n, a) => n + (a as List).length);
  final kb = (File(assetPath).lengthSync() / 1024).toStringAsFixed(1);
  final status = <String, int>{};
  for (final r in rows) {
    status[r.neStatus] = (status[r.neStatus] ?? 0) + 1;
  }
  stdout
    ..writeln()
    ..writeln(
      '✓ $assetPath  $kb KB  (${arcs.length} arcs, $points points, '
      'simplify $simplify)',
    );
  for (final MapEntry(key: level, value: object) in objectNames.entries) {
    final n = _geometries(topo, object).length;
    stdout.writeln('    $object: $n  (expected ${expectedCounts[level]})');
  }
  stdout
    ..writeln('✓ $regionsPath')
    ..writeln(
      '  Nepali names: ${status['verified'] ?? 0} verified, '
      '${status['draft'] ?? 0} draft, ${status['missing'] ?? 0} missing',
    );
  for (final w in warnings) {
    stdout.writeln('⚠ $w');
  }
}

/// The geometries of [object] in a TopoJSON [topology].
List<Map<String, dynamic>> _geometries(
  Map<String, dynamic> topology,
  String object,
) {
  final objects = topology['objects'] as Map<String, dynamic>;
  final o = objects[object] as Map<String, dynamic>;
  return (o['geometries'] as List).cast<Map<String, dynamic>>();
}

Never _fail(List<String> errors) {
  stderr.writeln('Build failed:');
  for (final e in errors) {
    stderr.writeln('  ✗ $e');
  }
  exit(1);
}
