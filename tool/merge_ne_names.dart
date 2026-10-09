// Merges Nepali names of local levels from a government list into
// tool/source/names.csv.
//
//   dart run tool/merge_ne_names.dart path/to/list.csv            # report only
//   dart run tool/merge_ne_names.dart path/to/list.csv --apply    # write names.csv
//   ... --apply --status=verified   # mark them verified instead of draft
//
// The list is a CSV with a `name_ne` column, plus either `code` (our codes)
// or `district` and `name_en`. Districts may be in English (any spelling in
// names.csv, including the source's, e.g. CHITAWAN) or Nepali. Type words
// (गाउँपालिका, Rural Municipality, …) are stripped. Unmatched rows and
// conflicts are reported; nothing is written without --apply. Run
// `dart run tool/build_data.dart` afterwards.

import 'dart:io';

import 'src/names.dart';
import 'src/ne_merge.dart';

const namesPath = 'tool/source/names.csv';

void main(List<String> args) {
  final input = args.where((a) => !a.startsWith('--')).firstOrNull;
  if (input == null) {
    stderr.writeln(
      'Usage: dart run tool/merge_ne_names.dart <list.csv> [--apply] [--status=draft|verified]',
    );
    exit(64);
  }
  final apply = args.contains('--apply');
  final status = args
      .firstWhere(
        (a) => a.startsWith('--status='),
        orElse: () => '--status=draft',
      )
      .split('=')[1];
  if (status != 'draft' && status != 'verified') {
    stderr.writeln('--status must be draft or verified');
    exit(64);
  }

  final rows = readNames(namesPath);
  final source = readSource(parseCsv(File(input).readAsStringSync()));
  final result = match(rows, source);
  final locals = rows.where((r) => r.level == 'local_level').toList();
  final stillMissing = locals
      .where((r) => r.nameNe.isEmpty && !result.matched.containsKey(r.code))
      .toList();

  stdout
    ..writeln('Source rows:        ${source.length}')
    ..writeln(
      'Matched:            ${result.matched.length} of ${locals.length} local levels',
    )
    ..writeln('  of which fuzzy:   ${result.fuzzy.length}')
    ..writeln('Unmatched rows:     ${result.unmatched.length}')
    ..writeln('Conflicts:          ${result.conflicts.length}')
    ..writeln('Changed names:      ${result.changed.length}')
    ..writeln('Still missing:      ${stillMissing.length}');
  if (result.fuzzy.isNotEmpty) {
    stdout.writeln('\nFuzzy matches (check these):');
    for (final (row, ours) in result.fuzzy) {
      stdout.writeln(
        '  line ${row.line}: "${row.nameEn}" (${row.district}) → $ours',
      );
    }
  }
  if (result.unmatched.isNotEmpty) {
    stdout.writeln('\nUnmatched rows:');
    for (final row in result.unmatched) {
      stdout.writeln(
        '  line ${row.line}: ${row.district ?? '-'} / ${row.nameEn ?? row.code ?? '-'} / ${row.nameNe}',
      );
    }
  }
  if (result.conflicts.isNotEmpty) {
    stdout.writeln('\nConflicts (not applied):');
    for (final MapEntry(:key, :value) in result.conflicts.entries) {
      stdout.writeln('  $key: ${value.join(' | ')}');
    }
  }
  if (result.changed.isNotEmpty) {
    stdout.writeln('\nNames that would change:');
    for (final MapEntry(key: code, value: (old, fresh))
        in result.changed.entries) {
      stdout.writeln('  $code: $old → $fresh');
    }
  }

  if (!apply) {
    stdout.writeln('\nReport only. Re-run with --apply to write $namesPath.');
    return;
  }
  final csv = parseCsv(File(namesPath).readAsStringSync());
  final header = csv.first;
  final updated = <Map<String, String>>[];
  for (final r in csv.skip(1)) {
    if (r.length == 1 && r.single.isEmpty) continue;
    final m = Map.fromIterables(header, r);
    final ne = result.matched[m['code']];
    if (ne != null && !result.conflicts.containsKey(m['code'])) {
      m['name_ne'] = ne;
      m['ne_status'] = status;
    }
    updated.add(m);
  }
  File(namesPath).writeAsStringSync(writeNames(header, updated));
  stdout.writeln('\nWrote $namesPath. Now run: dart run tool/build_data.dart');
}
