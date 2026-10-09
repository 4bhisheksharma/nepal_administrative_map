import 'dart:math' as math;

import '../../i18n/devanagari.dart';
import '../../i18n/map_language.dart';
import '../models/region.dart';

/// Searches region names in English (with alternative spellings) and Nepali.
///
/// Ranking, best first: exact match, prefix, word prefix, substring, then a
/// typo match (up to two edits, for queries of four or more characters).
/// Ties go to the larger region (province before district before local
/// level), then the shorter name.
class RegionSearch {
  RegionSearch._(this._entries);

  /// The index over every province, district and local level.
  static final RegionSearch instance = RegionSearch._([
    for (final r in <Region>[
      ...Province.values,
      ...District.values,
      ...LocalLevel.values,
    ])
      _Entry(r),
  ]);

  final List<_Entry> _entries;

  /// Regions matching [query], best first. Devanagari input matches Nepali
  /// names; anything else matches English names and aliases.
  List<Region> search(String query, {Set<AdminLevel>? levels, int limit = 10}) {
    final nepali = Devanagari.contains(query);
    final q = nepali ? Devanagari.normalize(query) : _latin(query);
    if (q.isEmpty || limit <= 0) return const [];

    final scored = <(int score, _Entry entry)>[];
    for (final entry in _entries) {
      if (levels != null && !levels.contains(entry.region.level)) continue;
      var best = 0;
      for (final key in nepali ? entry.ne : entry.en) {
        best = math.max(best, _score(key, q));
        if (best == _exact) break;
      }
      if (best > 0) scored.add((best, entry));
    }
    scored.sort((a, b) {
      final byScore = b.$1.compareTo(a.$1);
      if (byScore != 0) return byScore;
      final byLevel = a.$2.region.level.index.compareTo(
        b.$2.region.level.index,
      );
      if (byLevel != 0) return byLevel;
      return a.$2.region.name.en.length.compareTo(b.$2.region.name.en.length);
    });
    return [for (final (_, e) in scored.take(limit)) e.region];
  }

  static const _exact = 100;

  static int _score(String key, String q) {
    if (key == q) return _exact;
    if (key.startsWith(q)) return 80;
    if (key.contains(' $q')) return 60;
    if (key.contains(q)) return 40;
    if (q.length < 4) return 0;
    // Typo tolerance: compare with each word and with the key's start, so a
    // misspelled partial query ("pokahr") still matches.
    var distance = _osa(
      q,
      key.length > q.length ? key.substring(0, q.length) : key,
    );
    for (final word in key.split(' ')) {
      if (distance <= 1) break;
      distance = math.min(distance, _osa(q, word));
    }
    return distance <= 2 ? 20 - distance * 5 : 0;
  }

  /// Optimal string alignment distance (Levenshtein plus adjacent swaps).
  static int _osa(String a, String b) {
    if ((a.length - b.length).abs() > 2) return 3;
    final rows = List.generate(
      a.length + 1,
      (i) => List<int>.filled(b.length + 1, 0),
    );
    for (var i = 0; i <= a.length; i++) {
      rows[i][0] = i;
    }
    for (var j = 0; j <= b.length; j++) {
      rows[0][j] = j;
    }
    for (var i = 1; i <= a.length; i++) {
      for (var j = 1; j <= b.length; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        var d = math.min(
          math.min(rows[i - 1][j] + 1, rows[i][j - 1] + 1),
          rows[i - 1][j - 1] + cost,
        );
        if (i > 1 &&
            j > 1 &&
            a.codeUnitAt(i - 1) == b.codeUnitAt(j - 2) &&
            a.codeUnitAt(i - 2) == b.codeUnitAt(j - 1)) {
          d = math.min(d, rows[i - 2][j - 2] + 1);
        }
        rows[i][j] = d;
      }
    }
    return rows[a.length][b.length];
  }
}

final _nonAlphanumeric = RegExp('[^a-z0-9]+');

String _latin(String s) =>
    s.toLowerCase().replaceAll(_nonAlphanumeric, ' ').trim();

class _Entry {
  _Entry(this.region)
    : en = {
        _latin(region.name.en),
        _latin(region.fullName(MapLanguage.en)),
        for (final alias in regionAliases[region.code] ?? const <String>[])
          _latin(alias),
      }.toList(),
      ne = region.name.ne == region.name.en
          ? const [] // Nepali name not available yet
          : {
              Devanagari.normalize(region.name.ne),
              Devanagari.normalize(region.fullName(MapLanguage.ne)),
            }.toList();

  final Region region;
  final List<String> en;
  final List<String> ne;
}
