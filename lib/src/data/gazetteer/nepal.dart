import '../models/region.dart';
import 'search.dart';

/// Entry point to Nepal's administrative regions.
///
/// ```dart
/// Nepal.provinces;        // 7
/// Nepal.byCode('D305');   // District.kathmandu
/// ```
abstract final class Nepal {
  /// The 7 provinces, east to west.
  static List<Province> get provinces => Province.values;

  /// The 77 districts, in code order.
  static List<District> get districts => District.values;

  /// The 753 local levels, in code order.
  static List<LocalLevel> get localLevels => LocalLevel.values;

  /// The 10 protected areas that lie outside every local level.
  static List<ProtectedArea> get protectedAreas => ProtectedArea.values;

  /// The regions at [level].
  static List<Region> regionsAt(AdminLevel level) => switch (level) {
    AdminLevel.province => provinces,
    AdminLevel.district => districts,
    AdminLevel.localLevel => localLevels,
  };

  /// Regions whose names match [query], best first.
  ///
  /// Works in English (`'pokh'`, `'Pokhara'`, typos like `'pokahra'`, and
  /// old spellings like `'Chitawan'`) and Nepali (`'पोख'`, `'पोखरा'`).
  /// Limit the results to some [levels], and to [limit] regions.
  static List<Region> search(
    String query, {
    Set<AdminLevel>? levels,
    int limit = 10,
  }) => RegionSearch.instance.search(query, levels: levels, limit: limit);

  /// The province, district or local level with [code], or `null`.
  static Region? byCode(String code) => _regions[code];

  /// The protected area with [code] (e.g. `PA02`), or `null`.
  static ProtectedArea? protectedAreaByCode(String code) => _protected[code];

  /// Alternative spellings of the region or protected area with [code],
  /// e.g. `['Chitawan']` for Chitwan.
  static List<String> aliasesOf(String code) => regionAliases[code] ?? const [];

  static final Map<String, Region> _regions = {
    for (final r in <Region>[...provinces, ...districts, ...localLevels])
      r.code: r,
  };

  static final Map<String, ProtectedArea> _protected = {
    for (final p in protectedAreas) p.code: p,
  };
}
