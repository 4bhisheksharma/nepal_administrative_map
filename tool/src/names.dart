import 'dart:io';

/// One row of `tool/source/names.csv`.
class NameRow {
  NameRow(Map<String, String> m)
    : code = m['code']!,
      level = m['level']!,
      parentCode = m['parent_code']!,
      nameEn = m['name_en']!,
      nameNe = m['name_ne']!,
      neStatus = m['ne_status']!,
      type = m['type']!,
      aliases = _split(m['aliases']!),
      sourceKeys = _split(m['source_keys']!);

  final String code;
  final String level;
  final String parentCode;
  final String nameEn;
  final String nameNe;
  final String neStatus;
  final String type;
  final List<String> aliases;
  final List<String> sourceKeys;

  static List<String> _split(String s) =>
      s.isEmpty ? const [] : s.split(';').map((e) => e.trim()).toList();
}

/// Levels, in the order they appear in `names.csv`.
const levels = ['province', 'district', 'local_level', 'protected_area'];

const neStatuses = {'verified', 'draft', 'missing'};

/// Reads `names.csv`. Throws [FormatException] on malformed input.
List<NameRow> readNames(String path) {
  final records = parseCsv(File(path).readAsStringSync());
  final header = records.first;
  final rows = <NameRow>[];
  for (final (i, r) in records.skip(1).indexed) {
    if (r.length == 1 && r.single.isEmpty) continue; // blank line
    if (r.length != header.length) {
      throw FormatException(
        'names.csv line ${i + 2}: expected '
        '${header.length} fields, got ${r.length}',
      );
    }
    rows.add(NameRow(Map.fromIterables(header, r)));
  }
  return rows;
}

/// Minimal RFC 4180 CSV parser (quoted fields, escaped quotes, newlines).
List<List<String>> parseCsv(String input) {
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < input.length; i++) {
    final c = input[i];
    if (inQuotes) {
      if (c == '"') {
        if (i + 1 < input.length && input[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field.write(c);
      }
    } else if (c == '"') {
      inQuotes = true;
    } else if (c == ',') {
      row.add(field.toString());
      field.clear();
    } else if (c == '\n' || c == '\r') {
      if (c == '\r' && i + 1 < input.length && input[i + 1] == '\n') i++;
      row.add(field.toString());
      field.clear();
      rows.add(row);
      row = <String>[];
    } else {
      field.write(c);
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }
  return rows;
}
