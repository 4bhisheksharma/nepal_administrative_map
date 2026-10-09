import 'dart:math' as math;

import 'names.dart';

/// Type words dropped before matching, because `names.csv` stores short
/// names ("Pokhara", "पोखरा") without them.
const _typeWordsEn = [
  'sub metropolitan city',
  'metropolitan city',
  'rural municipality',
  'municipality',
  'upamahanagarpalika',
  'mahanagarpalika',
  'nagarpalika',
  'gaunpalika',
  'gaupalika',
];
const _typeWordsNe = [
  'उपमहानगरपालिका',
  'महानगरपालिका',
  'नगरपालिका',
  'गाउँपालिका',
  'गाउंपालिका',
];

/// `'Aathrai Tribeni Rural Municipality'` → `'aathraitribeni'`.
String normalizeEn(String s) {
  var t = s.toLowerCase().replaceAll(RegExp('[^a-z ]'), ' ');
  for (final w in _typeWordsEn) {
    t = t.replaceAll(w, ' ');
  }
  return t.replaceAll(' ', '');
}

/// Strips the type word and extra spaces from a Nepali name.
String shortNe(String s) {
  var t = s.trim();
  for (final w in _typeWordsNe) {
    if (t.endsWith(w)) t = t.substring(0, t.length - w.length);
  }
  return t.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// One row of the government list, after reading its CSV.
class SourceRow {
  SourceRow({
    this.code,
    this.district,
    this.nameEn,
    required this.nameNe,
    required this.line,
  });

  final String? code;
  final String? district;
  final String? nameEn;
  final String nameNe;
  final int line;
}

/// The outcome of matching a government list against `names.csv`.
class MergeResult {
  /// Local-level code → Nepali short name.
  final matched = <String, String>{};

  /// Matches that needed fuzzy spelling: (row, our English name).
  final fuzzy = <(SourceRow, String)>[];

  /// Rows that matched nothing.
  final unmatched = <SourceRow>[];

  /// Codes matched by more than one row with different names.
  final conflicts = <String, Set<String>>{};

  /// Codes whose existing (non-empty) Nepali name differs from the list.
  final changed = <String, (String old, String fresh)>{};
}

/// Reads a government list. Required column: `name_ne`. Then either `code`,
/// or `name_en` with `district` (English, any spelling we know, or Nepali).
List<SourceRow> readSource(List<List<String>> csv) {
  final header = [for (final h in csv.first) h.trim().toLowerCase()];
  int? col(String name) => header.contains(name) ? header.indexOf(name) : null;
  final ne =
      col('name_ne') ??
      (throw const FormatException('The list needs a name_ne column'));
  final code = col('code'), district = col('district'), en = col('name_en');
  if (code == null && (district == null || en == null)) {
    throw const FormatException(
      'The list needs a code column, or district and name_en columns',
    );
  }
  String? at(List<String> r, int? i) =>
      i == null || i >= r.length || r[i].trim().isEmpty ? null : r[i].trim();
  return [
    for (final (i, r) in csv.skip(1).indexed)
      if (at(r, ne) case final name?)
        SourceRow(
          code: at(r, code),
          district: at(r, district),
          nameEn: at(r, en),
          nameNe: name,
          line: i + 2,
        ),
  ];
}

/// Matches [source] rows to local levels in [rows].
MergeResult match(List<NameRow> rows, List<SourceRow> source) {
  final result = MergeResult();
  final byCode = {for (final r in rows) r.code: r};
  // Every way we know to write each district: English, aliases, Nepali.
  final districtKey = <String, String>{};
  for (final d in rows.where((r) => r.level == 'district')) {
    for (final name in [d.nameEn, ...d.aliases, ...d.sourceKeys]) {
      districtKey[normalizeEn(name)] = d.code;
    }
    if (d.nameNe.isNotEmpty) districtKey[d.nameNe.trim()] = d.code;
  }
  final localByDistrict = <String, List<NameRow>>{};
  for (final l in rows.where((r) => r.level == 'local_level')) {
    (localByDistrict[l.parentCode] ??= []).add(l);
  }

  void record(String code, String ne) {
    final fresh = shortNe(ne);
    final previous = result.matched[code];
    if (previous != null && previous != fresh) {
      (result.conflicts[code] ??= {previous}).add(fresh);
      return;
    }
    result.matched[code] = fresh;
    final old = byCode[code]!.nameNe;
    if (old.isNotEmpty && old != fresh) result.changed[code] = (old, fresh);
  }

  for (final row in source) {
    if (row.code case final code? when byCode[code]?.level == 'local_level') {
      record(code, row.nameNe);
      continue;
    }
    final d = row.district == null
        ? null
        : districtKey[normalizeEn(row.district!)] ??
              districtKey[row.district!.trim()];
    final candidates = d == null
        ? const <NameRow>[]
        : localByDistrict[d] ?? const [];
    final want = row.nameEn == null ? null : normalizeEn(row.nameEn!);
    if (want == null || candidates.isEmpty) {
      result.unmatched.add(row);
      continue;
    }
    final exact = candidates.where(
      (c) =>
          normalizeEn(c.nameEn) == want ||
          c.aliases.any((a) => normalizeEn(a) == want),
    );
    if (exact.length == 1) {
      record(exact.single.code, row.nameNe);
      continue;
    }
    // Spelling differences within the district (e.g. "Aamchok"/"Aamchowk").
    final scored = [
      for (final c in candidates) (c, distance(want, normalizeEn(c.nameEn))),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    final best = scored.first;
    final unique = scored.length == 1 || scored[1].$2 > best.$2;
    if (best.$2 <= math.max(1, want.length ~/ 6) && unique) {
      record(best.$1.code, row.nameNe);
      result.fuzzy.add((row, best.$1.nameEn));
    } else {
      result.unmatched.add(row);
    }
  }
  return result;
}

/// Levenshtein distance.
int distance(String a, String b) {
  var previous = List<int>.generate(b.length + 1, (j) => j);
  for (var i = 1; i <= a.length; i++) {
    final current = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      current[j] = math.min(
        math.min(previous[j] + 1, current[j - 1] + 1),
        previous[j - 1] + cost,
      );
    }
    previous = current;
  }
  return previous[b.length];
}

/// Writes [rows] back as `names.csv`.
String writeNames(List<String> header, List<Map<String, String>> rows) {
  String quote(String v) =>
      v.contains(RegExp('[",\n]')) ? '"${v.replaceAll('"', '""')}"' : v;
  final lines = [
    header.join(','),
    for (final r in rows) [for (final h in header) quote(r[h] ?? '')].join(','),
  ];
  return '${lines.join('\n')}\n';
}
